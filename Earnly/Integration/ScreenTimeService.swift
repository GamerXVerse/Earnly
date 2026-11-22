import SwiftUI

/// Typed failures from the integration boundary. Mirrors `ScreenTimeServiceError`,
/// `LifecycleError`, `PracticeError` and `PersistenceError` without leaking them to views.
enum ServiceFailure: Error, Equatable {
    case denied, revoked, unavailable, requestFailed
    case invalidSelection, selectionNotFound
    case monitoringFailed, shieldFailed
    case configurationLocked
    case practiceUnavailable
    case conflictingSubmission
    case persistence
    case notConnected
    case unexpected(String)

    var userMessage: String {
        switch self {
        case .denied: return "Screen Time access was declined."
        case .revoked: return "Screen Time access was turned off."
        case .unavailable: return "Screen Time isn't available on this device right now."
        case .requestFailed: return "The request didn't go through. Try again in a moment."
        case .invalidSelection: return "Choose at least one app, category or website."
        case .selectionNotFound: return "That selection is no longer available. Choose again."
        case .monitoringFailed: return "Earnly couldn't start monitoring your selected apps."
        case .shieldFailed: return "Earnly couldn't change the restriction on your apps."
        case .configurationLocked: return "Finish your current practice and reward before changing this."
        case .practiceUnavailable: return "Practice sessions open when your selected apps are restricted."
        case .conflictingSubmission: return "That question already has a different saved answer."
        case .persistence: return "Earnly couldn't read or save its data."
        case .notConnected: return "Screen Time isn't connected in this build."
        case .unexpected(let detail): return detail.isEmpty ? "Something unexpected went wrong." : detail
        }
    }
}

enum SelectionPickerOutcome: Equatable {
    case selected(ActivitySelectionSummary)
    case cancelled
}

/// The only surface through which views reach production state.
///
/// Production adapter (Phase 2B, once `EarnlySystems` is linked) wraps `EarnlySystem` plus the
/// platform coordinator. `reconcile()` is the single call that re-reads authorization, checks
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
}

/// Used in release builds until the systems package is linked. It reports honestly that nothing
/// is connected; it never simulates a successful authorization or restriction.
@MainActor
final class DisconnectedScreenTimeService: ScreenTimeServicing {
    let isSimulated = false
    func snapshot() async throws -> ServiceSnapshot {
        var s = ServiceSnapshot.fresh(provenance: .observed)
        s.authorization = .unavailable
        s.stage = .authorizationUnavailable
        s.earnedMinutes = nil
        return s
    }
    func reconcile() async throws -> ServiceSnapshot { try await snapshot() }
    func requestAuthorization() async throws -> ServiceSnapshot { throw ServiceFailure.notConnected }
    func makeSelectionPicker(onFinish: @escaping @MainActor (SelectionPickerOutcome) -> Void) -> AnyView {
        AnyView(EmptyView())
    }
    func makeSelectionLabels() -> AnyView? { nil }
    func applySelection(_ selection: ActivitySelectionSummary, allowanceMinutes: Int) async throws -> ServiceSnapshot { throw ServiceFailure.notConnected }
    func updateAllowance(minutes: Int) async throws -> ServiceSnapshot { throw ServiceFailure.notConnected }
    func disableRestrictions() async throws -> ServiceSnapshot { throw ServiceFailure.notConnected }
    func startPractice() async throws -> PracticeSnapshot { throw ServiceFailure.notConnected }
    func submitAnswer(sessionID: UUID, questionID: String, answerID: String) async throws -> PracticeSnapshot { throw ServiceFailure.notConnected }
    func grantReward(sessionID: UUID) async throws -> ServiceSnapshot { throw ServiceFailure.notConnected }
    func retryPendingOperation() async throws -> ServiceSnapshot { throw ServiceFailure.notConnected }
}

enum ScreenTimeServiceFactory {
    /// Debug builds use the deterministic development adapter. Release builds cannot.
    @MainActor
    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> any ScreenTimeServicing {
        #if DEBUG
        return DevelopmentScreenTimeService.fromLaunchArguments(arguments)
        #else
        return DisconnectedScreenTimeService()
        #endif
    }
}
