import EarnlySystems
import SwiftUI

/// Typed failures from the integration boundary. Mirrors `ScreenTimeServiceError`,
/// `LifecycleError`, `PracticeError` and `PersistenceError` without leaking them to views.
enum ServiceFailure: Error, Equatable {
    case denied, revoked, unavailable, requestFailed
    case invalidSelection, selectionNotFound, unsafeSelection, invalidAllowance
    case monitoringFailed, shieldFailed
    case configurationLocked, monitoringInterrupted, operationInProgress
    case practiceUnavailable, insufficientQuestions(required: Int, available: Int)
    case conflictingSubmission
    case persistence
    case notConnected, unsupportedOS
    case unexpected(String)

    var userMessage: String {
        switch self {
        case .denied: return "Screen Time access was declined."
        case .revoked: return "Screen Time access was turned off."
        case .unavailable: return "Screen Time isn't available on this device right now."
        case .requestFailed: return "The request didn't go through. Try again in a moment."
        case .invalidSelection: return "Choose at least one individual app or website."
        case .unsafeSelection: return "Expand a category and choose the individual apps you want to track, or choose a website."
        case .invalidAllowance: return "Choose a 1-, 5-, 10-, or 15-minute allowance."
        case .selectionNotFound: return "That selection is no longer available. Choose again."
        case .monitoringFailed: return "Earnly couldn't start monitoring your selected apps."
        case .shieldFailed: return "Earnly couldn't change the restriction on your apps."
        case .monitoringInterrupted: return "Monitoring was interrupted. Turn off restrictions and choose your activities again."
        case .operationInProgress: return "Earnly is updating Screen Time. Try again in a moment."
        case .configurationLocked: return "Finish your current practice and reward before changing this."
        case .practiceUnavailable: return "Practice sessions open when your selected apps are restricted."
        case let .insufficientQuestions(required, available):
            return "Your selected exams have \(available) of the \(required) questions needed. Choose another exam in Settings."
        case .conflictingSubmission: return "That question already has a different saved answer."
        case .persistence: return "Earnly couldn't read or save its data."
        case .notConnected: return "Screen Time requires an iPhone build with Family Controls and an App Group."
        case .unsupportedOS: return "Earnly's Screen Time monitoring requires iOS 17.4 or later."
        case .unexpected(let detail): return detail.isEmpty ? "Something unexpected went wrong." : detail
        }
    }

    static func from(_ error: Error) -> ServiceFailure {
        switch error {
        case let failure as ServiceFailure: return failure
        case let failure as ScreenTimeServiceError:
            switch failure {
            case .denied: return .denied
            case .revoked: return .revoked
            case .unavailable: return .unavailable
            case .requestFailed: return .requestFailed
            case .invalidSelection: return .invalidSelection
            case .selectionNotFound: return .selectionNotFound
            case .unsafeSelection: return .unsafeSelection
            case .shieldingFailed: return .shieldFailed
            case .monitoringInterrupted: return .monitoringInterrupted
            case .monitoringFailed, .earlyThreshold, .unknownCycle: return .monitoringFailed
            case .unsupportedOS: return .unsupportedOS
            case .operationInProgress: return .operationInProgress
            case .invalidHostConfiguration: return .notConnected
            }
        case let failure as LifecycleError:
            switch failure {
            case .authorizationRequired(.denied): return .denied
            case .authorizationRequired(.revoked): return .revoked
            case .authorizationRequired: return .unavailable
            case .invalidSelection: return .invalidSelection
            case .configurationLocked: return .configurationLocked
            case .invalidTransition, .disabledPolicy: return .practiceUnavailable
            case .missingCredit: return .persistence
            }
        case let failure as PracticeError:
            switch failure {
            case let .insufficientQuestions(required, available): return .insufficientQuestions(required: required, available: available)
            case .alreadyAnswered: return .conflictingSubmission
            default: return .practiceUnavailable
            }
        case ScreenTimePersistenceError.containerUnavailable: return .notConnected
        case is PersistenceError, is ScreenTimePersistenceError, is RewardError: return .persistence
        case is PolicyError: return .invalidAllowance
        default: return .unexpected("")
        }
    }
}

enum SelectionPickerOutcome: Equatable {
    case selected(ActivitySelectionSummary)
    case cancelled
}

/// The only surface through which views reach production state.
///
/// The native adapter wraps the shared systems engine. `reconcile()` is the single call that re-reads authorization, checks
/// platform state and drives any pending operation, then returns authoritative state.
@MainActor
protocol ScreenTimeServicing: AnyObject {
    var isSimulated: Bool { get }

    func snapshot() async throws -> ServiceSnapshot
    func reconcile() async throws -> ServiceSnapshot

    /// Real adapter calls the systems-owned authorization service. Must never fake success.
    func requestAuthorization() async throws -> ServiceSnapshot

    /// A view that hosts Apple's `FamilyActivityPicker` (production) and reports the outcome.
    func makeSelectionPicker(onFinish: @escaping @MainActor (SelectionPickerOutcome) -> Void) -> AnyView
    /// Apple token labels for the saved selection, when the platform can render them.
    func makeSelectionLabels() -> AnyView?

    func applySelection(_ selection: ActivitySelectionSummary, allowanceMinutes: Int) async throws -> ServiceSnapshot
    func updateAllowance(minutes: Int) async throws -> ServiceSnapshot
    func disableRestrictions() async throws -> ServiceSnapshot

    func startPractice() async throws -> PracticeSnapshot
    func submitAnswer(sessionID: UUID, questionID: String, answerID: String) async throws -> PracticeSnapshot
    /// Idempotent per session: a repeat never creates another credit.
    func grantReward(sessionID: UUID) async throws -> ServiceSnapshot
    func retryPendingOperation() async throws -> ServiceSnapshot
    func loadStudyProfile() async -> PreviewStudyProfile?
    func saveStudyProfile(_ profile: PreviewStudyProfile) async throws
}

extension ScreenTimeServicing {
    func loadStudyProfile() async -> PreviewStudyProfile? { nil }
    func saveStudyProfile(_ profile: PreviewStudyProfile) async throws {}
}

/// Reports unavailable when the platform or this build cannot provide Screen Time.
@MainActor
final class DisconnectedScreenTimeService: ScreenTimeServicing {
    let isSimulated = false
    let failure: ServiceFailure

    init(failure: ServiceFailure = .notConnected) {
        self.failure = failure
    }

    func snapshot() async throws -> ServiceSnapshot {
        var s = ServiceSnapshot.fresh(provenance: .observed)
        s.authorization = .unavailable
        s.stage = .authorizationUnavailable
        s.earnedMinutes = nil
        return s
    }
    func reconcile() async throws -> ServiceSnapshot { try await snapshot() }
    func requestAuthorization() async throws -> ServiceSnapshot { throw failure }
    func makeSelectionPicker(onFinish: @escaping @MainActor (SelectionPickerOutcome) -> Void) -> AnyView {
        AnyView(EmptyView())
    }
    func makeSelectionLabels() -> AnyView? { nil }
    func applySelection(_ selection: ActivitySelectionSummary, allowanceMinutes: Int) async throws -> ServiceSnapshot { throw failure }
    func updateAllowance(minutes: Int) async throws -> ServiceSnapshot { throw failure }
    func disableRestrictions() async throws -> ServiceSnapshot { throw failure }
    func startPractice() async throws -> PracticeSnapshot { throw failure }
    func submitAnswer(sessionID: UUID, questionID: String, answerID: String) async throws -> PracticeSnapshot { throw failure }
    func grantReward(sessionID: UUID) async throws -> ServiceSnapshot { throw failure }
    func retryPendingOperation() async throws -> ServiceSnapshot { throw failure }
}

enum ScreenTimeServiceFactory {
    @MainActor
    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> any ScreenTimeServicing {
        #if DEBUG
        let simulationArguments: Set<String> = [
            "-earnly-demo", "-earnly-fixture", "-earnly-skip-onboarding", "-earnly-no-latency", "-earnly-fresh-defaults"
        ]
        if arguments.contains(where: simulationArguments.contains) {
            return DevelopmentScreenTimeService.fromLaunchArguments(arguments)
        }
        #endif

        #if targetEnvironment(simulator)
        return DisconnectedScreenTimeService(failure: .unavailable)
        #else
        guard #available(iOS 17.4, *) else { return DisconnectedScreenTimeService(failure: .unsupportedOS) }
        guard let host = Bundle.main.bundleIdentifier,
              let group = Bundle.main.object(forInfoDictionaryKey: "EarnlyAppGroupIdentifier") as? String,
              !group.isEmpty else { return DisconnectedScreenTimeService() }
        do {
            let directory = URL.applicationSupportDirectory.appendingPathComponent("Earnly", isDirectory: true)
            let engine = try AppleScreenTimeEngine(
                fileURL: directory.appendingPathComponent("learning.json"),
                appGroupIdentifier: group, hostBundleIdentifier: host
            )
            return NativeScreenTimeService(engine: engine)
        } catch {
            return DisconnectedScreenTimeService(failure: .from(error))
        }
        #endif
    }
}
