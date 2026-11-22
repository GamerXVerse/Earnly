import EarnlySystems
import FamilyControls
import SwiftUI

/// Translates the shared engine into the frontend's existing presentation contract.
@MainActor
final class NativeScreenTimeService: ScreenTimeServicing {
    let isSimulated = false
    private let engine: AppleScreenTimeEngine
    private var draft: (id: UUID, selection: FamilyActivitySelection)?

    init(engine: AppleScreenTimeEngine) {
        self.engine = engine
    }

    func snapshot() async -> ServiceSnapshot { await makeSnapshot() }

    func reconcile() async throws -> ServiceSnapshot {
        try await translated {
            do {
                try await engine.appDidBecomeActive()
            } catch ScreenTimeServiceError.operationInProgress {
                // A system authorization sheet can reactivate the scene during its own request.
                // The in-flight command will publish its result when it finishes.
            }
            return await makeSnapshot()
        }
    }

    func requestAuthorization() async throws -> ServiceSnapshot {
        try await translated {
            _ = try await engine.requestAuthorization()
            return await makeSnapshot()
        }
    }

    func makeSelectionPicker(onFinish: @escaping @MainActor (SelectionPickerOutcome) -> Void) -> AnyView {
        do {
            return AnyView(NativeSelectionPicker(selection: try engine.pickerSelection()) { selection in
                guard let selection else {
                    self.draft = nil
                    onFinish(.cancelled)
                    return
                }
                let id = UUID()
                self.draft = (id, selection)
                onFinish(.selected(ActivitySelectionSummary(
                    id: id, applications: selection.applicationTokens.count,
                    categories: selection.categoryTokens.count, webDomains: selection.webDomainTokens.count
                )))
            })
        } catch {
            return AnyView(
                VStack(alignment: .leading, spacing: EarnlySpacing.lg) {
                    EarnlyStatusMessage(kind: .warning, text: ServiceFailure.from(error).userMessage)
                    EarnlyButton(title: "Close", kind: .secondary) { onFinish(.cancelled) }
                }
                .padding(EarnlySpacing.lg)
            )
        }
    }

    func makeSelectionLabels() -> AnyView? {
        guard let selection = try? engine.pickerSelection(), !selection.applicationTokens.isEmpty
                || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty else { return nil }
        return AnyView(VStack(alignment: .leading, spacing: EarnlySpacing.sm) {
            ForEach(Array(selection.applicationTokens), id: \.self) { Label($0) }
            ForEach(Array(selection.categoryTokens), id: \.self) { Label($0) }
            ForEach(Array(selection.webDomainTokens), id: \.self) { Label($0) }
        }
        .font(EarnlyFont.secondary)
        .foregroundStyle(EarnlyColor.inkSecondary))
    }

    func applySelection(_ summary: ActivitySelectionSummary, allowanceMinutes: Int) async throws -> ServiceSnapshot {
        guard let draft, draft.id == summary.id else { throw ServiceFailure.selectionNotFound }
        self.draft = nil
        return try await translated {
            let snapshot = await engine.dashboard()
            try Self.checkReconfiguration(snapshot)
            let policy = try Self.policy(minutes: allowanceMinutes, previous: snapshot.dashboard.policy)
            try await engine.configure(policy: policy, selection: draft.selection)
            return await makeSnapshot()
        }
    }

    func updateAllowance(minutes: Int) async throws -> ServiceSnapshot {
        guard let allowance = InitialAllowance(rawValue: minutes) else { throw ServiceFailure.invalidAllowance }
        return try await translated {
            let snapshot = await engine.dashboard()
            try Self.checkReconfiguration(snapshot)
            if snapshot.dashboard.selection == nil {
                try await engine.setUnconfiguredAllowance(allowance)
            } else {
                let policy = try Self.policy(minutes: minutes, previous: snapshot.dashboard.policy)
                try await engine.configure(policy: policy, selection: engine.pickerSelection())
            }
            return await makeSnapshot()
        }
    }

    func disableRestrictions() async throws -> ServiceSnapshot {
        try await translated {
            try await engine.disable()
            return await makeSnapshot()
        }
    }

    func startPractice() async throws -> PracticeSnapshot {
        try await translated {
            let native = await engine.dashboard()
            guard native.monitoring == .shielded else { throw ServiceFailure.practiceUnavailable }
            return Self.practice(try await engine.system.startPractice())
        }
    }

    func submitAnswer(sessionID: UUID, questionID: String, answerID: String) async throws -> PracticeSnapshot {
        try await translated {
            Self.practice(try await engine.system.submitAnswer(
                sessionID: sessionID, questionID: questionID, answerID: answerID
            ))
        }
    }

    func grantReward(sessionID: UUID) async throws -> ServiceSnapshot {
        try await translated {
            _ = try await engine.finishPractice(sessionID: sessionID)
            return await makeSnapshot()
        }
    }

    func retryPendingOperation() async throws -> ServiceSnapshot {
        try await translated {
            try await engine.retry()
            return await makeSnapshot()
        }
    }

    func loadStudyProfile() async -> PreviewStudyProfile? {
        let stored = await engine.system.studyProfile()
        var exams: Set<PreviewExam> = []
        var subjects: Set<PreviewAPSubject> = []
        for exam in stored.exams {
            switch exam {
            case .sat: exams.insert(.sat)
            case .psat: exams.insert(.psat)
            case .act: exams.insert(.act)
            case let .ap(subjectCode):
                if let subject = PreviewAPSubject.allCases.first(where: { $0.systemCode == subjectCode }) {
                    exams.insert(.ap)
                    subjects.insert(subject)
                }
            }
        }
        return PreviewStudyProfile(selectedExams: exams, selectedAPSubjects: subjects)
    }

    func saveStudyProfile(_ profile: PreviewStudyProfile) async throws {
        let exams = Self.exams(from: profile)
        try await translated {
            let current = await engine.system.studyProfile()
            try await engine.system.saveStudyProfile(StudyProfile(exams: exams, preferredDifficulty: current.preferredDifficulty))
        }
    }

    static func exams(from selection: PreviewStudyProfile) -> Set<ExamType> {
        var exams: Set<ExamType> = []
        if selection.selectedExams.contains(.sat) { exams.insert(.sat) }
        if selection.selectedExams.contains(.psat) { exams.insert(.psat) }
        if selection.selectedExams.contains(.act) { exams.insert(.act) }
        for subject in selection.selectedAPSubjects {
            exams.insert(.ap(subjectCode: subject.systemCode))
        }
        return exams
    }

    private func makeSnapshot() async -> ServiceSnapshot {
        let native = await engine.dashboard()
        let dashboard = native.dashboard
        let cycle = await engine.system.currentCycle()
        let credits = await engine.system.rewardLedger().transactions
        var snapshot = ServiceSnapshot.fresh(provenance: .observed)
        snapshot.authorization = AuthorizationStatus(rawValue: dashboard.authorization.rawValue) ?? .unavailable
        snapshot.stage = Self.stage(dashboard.restriction, monitoring: native.monitoring)
        snapshot.policy = PolicySummary(
            allowanceMinutes: dashboard.policy.initialAllowance.rawValue,
            requiredQuestions: dashboard.policy.requiredQuestions, rewardMinutes: dashboard.policy.rewardedMinutes,
            isEnabled: dashboard.policy.isEnabled
        )
        snapshot.selection = dashboard.selection.map {
            ActivitySelectionSummary(id: $0.id, applications: $0.applicationCount,
                                     categories: $0.categoryCount, webDomains: $0.webDomainCount)
        }
        snapshot.cycleID = cycle?.id
        snapshot.activeSession = dashboard.activeSession.map(Self.practice)
        snapshot.earnedMinutes = Self.minutes(dashboard.earnedMinutes)
        snapshot.thresholdEvidenceMinutes = Self.minutes(dashboard.mostRecentThresholdMinutes)

        if let sessionID = cycle?.rewardSessionID, let credit = credits[sessionID] {
            if credit.activatedAt == nil {
                snapshot.pendingReward = PendingReward(sessionID: sessionID, minutes: credit.earnedMinutes,
                                                       releaseFailed: native.rewardReleasePending && snapshot.stage == .failed(.shield))
            } else if case let .registered(confirmed) = native.monitoring, cycle?.id == confirmed.id {
                snapshot.releasedRewardMinutes = credit.earnedMinutes
            }
        }

        let history = credits.values.sorted {
            if $0.earnedAt == $1.earnedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.earnedAt > $1.earnedAt
        }
        for credit in history {
            guard let session = try? await engine.system.session(id: credit.sessionID) else { continue }
            snapshot.rewardHistory.append(RewardEntry(
                id: credit.id, earnedAt: credit.earnedAt, minutes: credit.earnedMinutes,
                correct: session.correctAnswers, total: session.requiredQuestions,
                thresholdReached: credit.thresholdReachedAt != nil
            ))
        }
        return snapshot
    }

    static func stage(_ state: RestrictionState, monitoring: NativeMonitoringStatus) -> LifecycleStage {
        if monitoring == .cleanupPending { return .failed(.cleanupPending) }
        switch state {
        case .unconfigured: return .unconfigured
        case .configuring: return .configuring
        case .selectionRequired: return .selectionRequired
        case let .available(cycle):
            return monitoring == .registered(cycle) ? .available : .failed(.monitoringInterrupted)
        case .applyingShield: return .applyingShield
        case .restricted: return monitoring == .shielded ? .restricted : .failed(.shield)
        case .practiceInProgress: return monitoring == .shielded ? .practiceInProgress : .failed(.shield)
        case .rewardPending: return .rewardPending
        case .authorizationUnavailable: return .authorizationUnavailable
        case let .failed(failure):
            switch failure {
            case .monitoring: return .failed(.monitoring)
            case .shield: return .failed(.shield)
            case .thresholdBeforeRelease: return .failed(.thresholdBeforeRelease)
            case .monitoringInterrupted: return .failed(.monitoringInterrupted)
            }
        }
    }

    private static func practice(_ session: PracticeSession) -> PracticeSnapshot {
        PracticeSnapshot(
            id: session.id,
            questions: session.questions.map { question in
                PracticeQuestion(
                    id: question.id, label: question.topic, stem: question.stem,
                    options: question.options.map { PracticeOption(id: $0.id, text: $0.text) },
                    correctAnswerID: question.correctAnswerID, explanation: question.explanation
                )
            },
            attempts: session.attempts.map {
                PracticeAttempt(questionID: $0.questionID, answerID: $0.answerID, isCorrect: $0.isCorrect)
            },
            rewardMinutes: session.rewardMinutes, isComplete: session.isComplete
        )
    }

    private static func checkReconfiguration(_ snapshot: NativeDashboard) throws {
        switch snapshot.dashboard.restriction {
        case .practiceInProgress, .rewardPending, .applyingShield:
            throw ServiceFailure.configurationLocked
        case .failed where snapshot.dashboard.activeSession != nil:
            throw ServiceFailure.configurationLocked
        default:
            break
        }
    }

    private static func policy(minutes: Int, previous: ScreenTimePolicy) throws -> ScreenTimePolicy {
        guard let allowance = InitialAllowance(rawValue: minutes) else { throw ServiceFailure.invalidAllowance }
        return try ScreenTimePolicy(initialAllowance: allowance, requiredQuestions: previous.requiredQuestions,
                                    rewardedMinutes: previous.rewardedMinutes)
    }

    private static func minutes(_ value: DashboardValue<Int>) -> Int? {
        if case let .available(value, _) = value { return value }
        return nil
    }

    private func translated<T>(_ action: () async throws -> T) async throws -> T {
        do { return try await action() }
        catch { throw ServiceFailure.from(error) }
    }
}

private struct NativeSelectionPicker: View {
    @State var selection: FamilyActivitySelection
    let onFinish: (FamilyActivitySelection?) -> Void

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(
                headerText: "Choose individual apps or websites.",
                footerText: "Earnly keeps these selections on this device.", selection: $selection
            )
            .navigationTitle("Choose activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onFinish(nil) } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { onFinish(selection) } }
            }
        }
        .tint(EarnlyColor.brandText)
    }
}

private extension PreviewAPSubject {
    var systemCode: String {
        switch self {
        case .calculusAB: "calculus-ab"
        case .biology: "biology"
        case .chemistry: "chemistry"
        case .englishLanguage: "english-language"
        case .psychology: "psychology"
        case .usHistory: "us-history"
        }
    }
}
