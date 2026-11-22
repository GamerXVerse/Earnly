#if DEBUG
import SwiftUI

/// Deterministic fixtures for frontend verification. Debug builds only.
enum DevelopmentFixture: String, CaseIterable, Identifiable {
    case freshInstall, authorizationDenied, authorizationRevoked, selectionEmpty
    case monitoringPending, monitoringFailure
    case allowanceActive, allowanceActiveWithHistory, thresholdReached
    case interruptedPractice, rewardPending, releaseFailure, releaseSuccess

    var id: String { rawValue }

    var title: String {
        switch self {
        case .freshInstall: return "Fresh install"
        case .authorizationDenied: return "Authorization denied"
        case .authorizationRevoked: return "Authorization revoked"
        case .selectionEmpty: return "Selection empty"
        case .monitoringPending: return "Monitoring pending"
        case .monitoringFailure: return "Monitoring failure"
        case .allowanceActive: return "Allowance active"
        case .allowanceActiveWithHistory: return "Allowance active, with history"
        case .thresholdReached: return "Threshold reached (restricted)"
        case .interruptedPractice: return "Interrupted practice"
        case .rewardPending: return "Reward pending"
        case .releaseFailure: return "Shield release failure"
        case .releaseSuccess: return "Successful release"
        }
    }
}

/// In-memory stand-in for the systems package. It follows the documented contract
/// (idempotent credits, authorization-gated practice, locked configuration) so frontend
/// behavior can be verified without a device. It is not a production state machine.
@MainActor
final class DevelopmentScreenTimeService: ScreenTimeServicing {
    let isSimulated = true

    private(set) var state: ServiceSnapshot
    private(set) var grantedSessions: Set<UUID> = []
    private(set) var rewardGrantCount = 0
    /// Result of the next `requestAuthorization()` call.
    var nextAuthorizationResult: AuthorizationStatus = .approved
    var failNextRelease = false
    var failNextMonitoring = false
    /// Fixture hold flags keep a transitional state visible for inspection.
    var holdConfiguring = false
    var holdRelease = false
    var latency: Duration

    init(fixture: DevelopmentFixture = .freshInstall, latency: Duration = .milliseconds(350)) {
        self.latency = latency
        self.state = ServiceSnapshot.fresh(provenance: .simulated)
        apply(fixture)
    }

    static func fromLaunchArguments(_ args: [String]) -> DevelopmentScreenTimeService {
        var fixture = DevelopmentFixture.freshInstall
        if let flag = args.firstIndex(of: "-earnly-fixture"), args.indices.contains(flag + 1),
           let value = DevelopmentFixture(rawValue: args[flag + 1]) {
            fixture = value
        }
        let service = DevelopmentScreenTimeService(fixture: fixture, latency: args.contains("-earnly-no-latency") ? .zero : .milliseconds(350))
        return service
    }

    // MARK: Fixtures

    func apply(_ fixture: DevelopmentFixture) {
        grantedSessions = []
        rewardGrantCount = 0
        failNextRelease = false
        failNextMonitoring = false
        holdConfiguring = (fixture == .monitoringPending)
        holdRelease = (fixture == .rewardPending)
        nextAuthorizationResult = .approved
        var s = ServiceSnapshot.fresh(provenance: .simulated)
        let selection = ActivitySelectionSummary(id: UUID(), applications: 2, categories: 1, webDomains: 0)
        let cycle = UUID()
        func approved() { s.authorization = .approved; s.selection = selection; s.cycleID = cycle }

        switch fixture {
        case .freshInstall: break
        case .authorizationDenied: s.authorization = .denied; s.stage = .authorizationUnavailable
        case .authorizationRevoked:
            s.authorization = .revoked; s.stage = .authorizationUnavailable; s.earnedMinutes = 20
        case .selectionEmpty: s.authorization = .approved
        case .monitoringPending: approved(); s.stage = .configuring
        case .monitoringFailure: approved(); s.stage = .failed(.monitoring)
        case .allowanceActive: approved(); s.stage = .available
        case .allowanceActiveWithHistory:
            approved(); s.stage = .available; s.earnedMinutes = 30
            s.rewardHistory = Self.sampleHistory
        case .thresholdReached: approved(); s.stage = .restricted; s.thresholdEvidenceMinutes = 10
        case .interruptedPractice:
            approved(); s.stage = .practiceInProgress; s.thresholdEvidenceMinutes = 10
            s.activeSession = Self.session(answered: 4, complete: false)
        case .rewardPending:
            approved(); s.stage = .rewardPending
            let session = Self.session(answered: 10, complete: true)
            s.activeSession = session
            s.pendingReward = PendingReward(sessionID: session.id, minutes: 10, releaseFailed: false)
            s.earnedMinutes = 10
            grantedSessions = [session.id]
        case .releaseFailure:
            approved(); s.stage = .failed(.shield)
            let session = Self.session(answered: 10, complete: true)
            s.activeSession = session
            s.pendingReward = PendingReward(sessionID: session.id, minutes: 10, releaseFailed: true)
            s.earnedMinutes = 10
            grantedSessions = [session.id]
        case .releaseSuccess:
            approved(); s.stage = .available; s.releasedRewardMinutes = 10; s.earnedMinutes = 10
            s.activeSession = Self.session(answered: 10, complete: true)
        }
        state = s
    }

    // MARK: ScreenTimeServicing

    func snapshot() async throws -> ServiceSnapshot { state }

    func reconcile() async throws -> ServiceSnapshot {
        try await pause()
        switch state.stage {
        case .configuring where !holdConfiguring:
            if failNextMonitoring { failNextMonitoring = false; state.stage = .failed(.monitoring) }
            else { state.stage = .available }
        case .rewardPending where !holdRelease:
            guard var reward = state.pendingReward else { break }
            if failNextRelease {
                failNextRelease = false
                reward.releaseFailed = true
                state.pendingReward = reward
                state.stage = .failed(.shield)
            } else {
                state.releasedRewardMinutes = reward.minutes
                state.pendingReward = nil
                state.stage = .available
            }
        default: break
        }
        return state
    }

    func requestAuthorization() async throws -> ServiceSnapshot {
        try await pause()
        guard state.authorization == .notDetermined else {
            // Mirrors the platform: a decided state is not prompted again.
            return state
        }
        state.authorization = nextAuthorizationResult
        switch nextAuthorizationResult {
        case .denied: state.stage = .authorizationUnavailable; throw ServiceFailure.denied
        case .unavailable: state.stage = .authorizationUnavailable; throw ServiceFailure.unavailable
        default: return state
        }
    }

    func makeSelectionPicker(onFinish: @escaping @MainActor (SelectionPickerOutcome) -> Void) -> AnyView {
        AnyView(DevelopmentPickerSheet(onFinish: onFinish))
    }

    func makeSelectionLabels() -> AnyView? { nil }

    func applySelection(_ selection: ActivitySelectionSummary, allowanceMinutes: Int) async throws -> ServiceSnapshot {
        try await pause()
        guard state.authorization == .approved else { throw ServiceFailure.unavailable }
        guard !selection.isEmpty else { throw ServiceFailure.invalidSelection }
        switch state.stage {
        case .unconfigured, .selectionRequired, .authorizationUnavailable:
            state.policy.allowanceMinutes = allowanceMinutes
            state.selection = selection
            state.cycleID = UUID()
            state.stage = .configuring
        default:
            guard canReconfigure else { throw ServiceFailure.configurationLocked }
            state.selection = selection
            state.cycleID = UUID()
            state.stage = .configuring
        }
        return state
    }

    func updateAllowance(minutes: Int) async throws -> ServiceSnapshot {
        try await pause()
        guard PolicySummary.allowanceOptions.contains(minutes) else { throw ServiceFailure.unexpected("Unsupported allowance.") }
        if state.stage == .unconfigured || state.selection == nil {
            state.policy.allowanceMinutes = minutes
            return state
        }
        guard canReconfigure else { throw ServiceFailure.configurationLocked }
        state.policy.allowanceMinutes = minutes
        state.cycleID = UUID()
        state.stage = .configuring
        return state
    }

    func disableRestrictions() async throws -> ServiceSnapshot {
        try await pause()
        guard canReconfigure else { throw ServiceFailure.configurationLocked }
        state.stage = .unconfigured
        state.selection = nil
        state.cycleID = nil
        return state
    }

    func startPractice() async throws -> PracticeSnapshot {
        try await pause()
        guard state.authorization == .approved else { throw ServiceFailure.practiceUnavailable }
        if state.stage == .practiceInProgress, let session = state.activeSession { return session }
        guard state.stage == .restricted else { throw ServiceFailure.practiceUnavailable }
        let session = Self.session(answered: 0, complete: false, rewardMinutes: state.policy.rewardMinutes)
        state.activeSession = session
        state.stage = .practiceInProgress
        return session
    }

    func submitAnswer(sessionID: UUID, questionID: String, answerID: String) async throws -> PracticeSnapshot {
        try await pause()
        guard let session = state.activeSession, session.id == sessionID else { throw ServiceFailure.practiceUnavailable }
        if let existing = session.attempts.first(where: { $0.questionID == questionID }) {
            guard existing.answerID == answerID else { throw ServiceFailure.conflictingSubmission }
            return session
        }
        guard let question = session.questions.first(where: { $0.id == questionID }) else { throw ServiceFailure.practiceUnavailable }
        let attempts = session.attempts + [PracticeAttempt(questionID: questionID, answerID: answerID, isCorrect: answerID == question.correctAnswerID)]
        let complete = attempts.count == session.questions.count
        let updated = PracticeSnapshot(id: session.id, questions: session.questions, attempts: attempts,
                                       rewardMinutes: session.rewardMinutes, isComplete: complete)
        state.activeSession = updated
        if complete { state.stage = .rewardPending }
        return updated
    }

    func grantReward(sessionID: UUID) async throws -> ServiceSnapshot {
        try await pause()
        guard let session = state.activeSession, session.id == sessionID, session.isComplete else {
            throw ServiceFailure.practiceUnavailable
        }
        guard !grantedSessions.contains(sessionID) else { return state }   // idempotent
        grantedSessions.insert(sessionID)
        rewardGrantCount += 1
        state.earnedMinutes = (state.earnedMinutes ?? 0) + session.rewardMinutes
        state.pendingReward = PendingReward(sessionID: sessionID, minutes: session.rewardMinutes, releaseFailed: false)
        state.stage = .rewardPending
        return state
    }

    func retryPendingOperation() async throws -> ServiceSnapshot {
        try await pause()
        holdConfiguring = false
        holdRelease = false
        switch state.stage {
        case .failed(.shield):
            state.pendingReward?.releaseFailed = false
            state.stage = state.pendingReward == nil ? .restricted : .rewardPending
        case .failed(.monitoring), .failed(.thresholdBeforeRelease):
            state.stage = .configuring
        default: break
        }
        return state
    }

    private var canReconfigure: Bool {
        switch state.stage {
        case .practiceInProgress, .rewardPending, .applyingShield: return false
        case .failed(.shield): return state.pendingReward == nil
        default: return true
        }
    }

    private func pause() async throws {
        if latency > .zero { try? await Task.sleep(for: latency) }
    }

    // MARK: Fixture content (original sample questions)

    private static let sampleID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!

    static func session(answered: Int, complete: Bool, rewardMinutes: Int = 10) -> PracticeSnapshot {
        let attempts = questions.prefix(answered).enumerated().map { index, q in
            // Deterministic: the third and seventh answers are wrong so feedback is exercised.
            let wrong = index == 2 || index == 6
            let answer = wrong ? q.options.first { $0.id != q.correctAnswerID }!.id : q.correctAnswerID
            return PracticeAttempt(questionID: q.id, answerID: answer, isCorrect: !wrong)
        }
        return PracticeSnapshot(id: sampleID, questions: questions, attempts: attempts,
                                rewardMinutes: rewardMinutes, isComplete: complete)
    }

    static var sampleHistory: [RewardEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let rows: [(Int, Int, Int)] = [(6, 7, 10), (4, 8, 10), (1, 9, 10)]
        return rows.map { daysAgo, correct, total in
            RewardEntry(id: UUID(), earnedAt: cal.date(byAdding: .day, value: -daysAgo, to: today)!,
                        minutes: 10, correct: correct, total: total, thresholdReached: daysAgo > 1)
        }
    }

    static let questions: [PracticeQuestion] = {
        func q(_ n: Int, _ section: String, _ stem: String, _ choices: [String], _ correct: Int, _ why: String) -> PracticeQuestion {
            let ids = ["a", "b", "c", "d"]
            return PracticeQuestion(
                id: "dev-\(n)", label: "SAT · \(section)", stem: stem,
                options: zip(ids, choices).map { PracticeOption(id: $0, text: $1) },
                correctAnswerID: ids[correct], explanation: why)
        }
        return [
            q(1, "Math", "A phone plan costs $20 per month plus $5 for each gigabyte of data. Last month the bill was $55. How many gigabytes were used?", ["5", "6", "7", "8"], 2, "Subtract the $20 base: 55 − 20 = 35. Then divide by $5 per gigabyte: 35 ÷ 5 = 7."),
            q(2, "Math", "What is 15% of 80?", ["8", "10", "12", "15"], 2, "15% is 0.15, and 0.15 × 80 = 12."),
            q(3, "Math", "At what point does the line y = 2x + 3 cross the y-axis?", ["(0, 2)", "(0, 3)", "(3, 0)", "(2, 3)"], 1, "The y-axis is where x = 0. Substituting gives y = 3, so the point is (0, 3)."),
            q(4, "Math", "If 3x + 7 = 22, what is the value of x?", ["3", "5", "7", "9"], 1, "Subtract 7 from both sides to get 3x = 15, then divide by 3: x = 5."),
            q(5, "Math", "If f(x) = x² − 4, what is f(3)?", ["2", "5", "9", "13"], 1, "Replace x with 3: 3² − 4 = 9 − 4 = 5."),
            q(6, "Math", "A rectangle is 8 units long and 5 units wide. What is its perimeter?", ["13", "26", "40", "45"], 1, "Perimeter is 2 × (length + width) = 2 × 13 = 26."),
            q(7, "Writing", "Which choice completes the sentence correctly?\n\nThe debate team ______ practicing every day since September.", ["has been", "have being", "are been", "were being"], 0, "“Team” is singular here, and “since September” calls for the present perfect progressive: “has been practicing.”"),
            q(8, "Reading", "Which word best completes the sentence?\n\nAlthough the first results were ______, the researchers repeated the experiment to be certain.", ["promising", "irrelevant", "hostile", "casual"], 0, "“Although” signals contrast. Results that looked good, but weren't yet confirmed, explain why the experiment was repeated."),
            q(9, "Writing", "Which revision of the underlined sentence is most concise?\n\n“Due to the fact that it was raining, the game was postponed.”", ["Because it rained, the game was postponed.", "The game, on account of rain, it was postponed.", "It was raining so the game was postponed because of that.", "Due to rain being the case, the game was postponed."], 0, "“Because it rained” replaces a wordy phrase with the same meaning and keeps the sentence grammatical."),
            q(10, "Reading", "Urban gardens can lower neighborhood temperatures and give residents fresh produce. Cities that support them often see more community involvement.\n\nWhich choice best states the main idea?", ["Urban gardens provide several benefits to cities.", "Fresh produce is cheaper in cities.", "Cities should replace all lawns.", "Community involvement is declining."], 0, "The passage lists cooler temperatures, fresh produce, and community involvement, all as benefits of urban gardens."),
        ]
    }()
}

/// Stand-in for Apple's picker so the surrounding flow can be exercised without entitlements.
/// Clearly labeled; production hosts `FamilyActivityPicker` here.
private struct DevelopmentPickerSheet: View {
    let onFinish: @MainActor (SelectionPickerOutcome) -> Void
    @State private var apps = 2
    @State private var categories = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper("Applications: \(apps)", value: $apps, in: 0...6)
                    Stepper("Categories: \(categories)", value: $categories, in: 0...3)
                } footer: {
                    Text("Development stand-in for Apple's activity picker. No real apps are selected.")
                }
            }
            .navigationTitle("Choose activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onFinish(.cancelled) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onFinish(.selected(ActivitySelectionSummary(id: UUID(), applications: apps, categories: categories, webDomains: 0)))
                    }
                }
            }
        }
    }
}
#endif
