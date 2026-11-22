import Foundation
import Observation

/// Shared presentation state. Production values come from `ScreenTimeServicing`;
/// this type only holds transient UI state (in-flight requests, last errors) and
/// forwards explicit user actions. It never decides that a restriction was applied,
/// a reward was granted or a session finished.
@MainActor
@Observable
final class AppModel {
    enum AuthorizationRequest: Equatable { case idle, requesting, failed(ServiceFailure) }
    enum SelectionFlow: Equatable { case idle, applying, cancelled, empty, failed(ServiceFailure) }
    enum Change: Equatable { case idle, applying(String), failed(ServiceFailure) }

    enum AuthorizationPresentation: Equatable {
        case notRequested, requesting, authorized, denied, revoked, unavailable, failed(String)
    }

    @ObservationIgnored let service: any ScreenTimeServicing
    @ObservationIgnored private let defaults: UserDefaults?

    private(set) var snapshot: ServiceSnapshot?
    private(set) var loadFailure: ServiceFailure?
    private(set) var authorizationRequest: AuthorizationRequest = .idle
    private(set) var selectionFlow: SelectionFlow = .idle
    private(set) var change: Change = .idle
    private(set) var isRetrying = false
    private(set) var rewardInFlight: Set<UUID> = []
    private(set) var rewardFailure: ServiceFailure?

    var profile: PreviewStudyProfile
    private(set) var hasCompletedOnboarding: Bool

    private static let onboardingKey = "earnly.onboardingComplete"

    init(
        service: any ScreenTimeServicing,
        profile: PreviewStudyProfile = PreviewStudyProfile(),
        hasCompletedOnboarding: Bool? = nil,
        defaults: UserDefaults? = .standard
    ) {
        self.service = service
        self.profile = profile
        self.defaults = defaults
        self.hasCompletedOnboarding = hasCompletedOnboarding ?? (defaults?.bool(forKey: Self.onboardingKey) ?? false)
    }

    // MARK: Derived presentation

    var dashboard: DashboardPresentation { .make(from: snapshot) }
    var isSimulated: Bool { service.isSimulated }

    var authorization: AuthorizationPresentation {
        switch authorizationRequest {
        case .requesting: return .requesting
        case .failed(let failure): return .failed(failure.userMessage)
        case .idle: break
        }
        switch snapshot?.authorization {
        case .approved: return .authorized
        case .denied: return .denied
        case .revoked: return .revoked
        case .unavailable: return .unavailable
        case .notDetermined, nil: return .notRequested
        }
    }

    var policy: PolicySummary { snapshot?.policy ?? .standard }

    /// The allowance the UI should show as selected, including one still being applied.
    var displayedAllowance: Int {
        if case .applying = change, let pending = pendingAllowance { return pending }
        return policy.allowanceMinutes
    }
    @ObservationIgnored private var pendingAllowance: Int?

    enum RewardOutcome: Equatable {
        case recording
        case restoring(minutes: Int)
        case releaseFailed(minutes: Int)
        case released(minutes: Int)
    }

    var rewardOutcome: RewardOutcome? {
        guard let s = snapshot else { return nil }
        if let reward = s.pendingReward {
            return reward.releaseFailed ? .releaseFailed(minutes: reward.minutes) : .restoring(minutes: reward.minutes)
        }
        if s.stage == .rewardPending, s.activeSession?.isComplete == true { return .recording }
        if s.stage == .available, let minutes = s.releasedRewardMinutes { return .released(minutes: minutes) }
        return nil
    }

    // MARK: Loading and reconciliation

    /// Call at launch and on every foreground entry.
    func reconcile() async {
        do {
            snapshot = try await service.reconcile()
            loadFailure = nil
        } catch let failure as ServiceFailure {
            loadFailure = failure
            if snapshot == nil { snapshot = try? await service.snapshot() }
        } catch {
            loadFailure = .unexpected(error.localizedDescription)
        }
        await finalizeRewardIfNeeded()
    }

    func refreshSnapshot() async {
        if let latest = try? await service.snapshot() { snapshot = latest }
    }

    /// A complete session whose credit was never recorded (for example the app was killed
    /// between the last answer and the grant). The grant is idempotent per session.
    private func finalizeRewardIfNeeded() async {
        guard let s = snapshot, s.stage == .rewardPending, s.pendingReward == nil,
              let session = s.activeSession, session.isComplete else { return }
        await completeReward(sessionID: session.id)
    }

    // MARK: Authorization

    func requestAuthorization() async {
        guard authorizationRequest != .requesting else { return }
        // A decided state is never prompted again; the UI offers iOS Settings instead.
        guard snapshot?.authorization == .notDetermined || snapshot == nil else { return }
        authorizationRequest = .requesting
        do {
            snapshot = try await service.requestAuthorization()
            authorizationRequest = .idle
        } catch let failure as ServiceFailure {
            await refreshSnapshot()
            switch failure {
            case .denied, .revoked, .unavailable: authorizationRequest = .idle
            default: authorizationRequest = .failed(failure)
            }
        } catch {
            authorizationRequest = .failed(.unexpected(error.localizedDescription))
        }
    }

    func clearAuthorizationError() {
        if case .failed = authorizationRequest { authorizationRequest = .idle }
    }

    // MARK: Selection

    func handlePickerOutcome(_ outcome: SelectionPickerOutcome) async {
        switch outcome {
        case .cancelled:
            selectionFlow = .cancelled
        case .selected(let selection):
            guard !selection.isEmpty else { selectionFlow = .empty; return }
            selectionFlow = .applying
            do {
                snapshot = try await service.applySelection(selection, allowanceMinutes: policy.allowanceMinutes)
                snapshot = try await service.reconcile()
                selectionFlow = .idle
            } catch let failure as ServiceFailure {
                selectionFlow = .failed(failure)
                await refreshSnapshot()
            } catch {
                selectionFlow = .failed(.unexpected(error.localizedDescription))
            }
        }
    }

    func clearSelectionFlow() { selectionFlow = .idle }

    // MARK: Policy

    func setAllowance(minutes: Int) async {
        guard minutes != displayedAllowance, change != .applying("Applying \(minutes)-minute allowance") else { return }
        pendingAllowance = minutes
        change = .applying("Applying \(minutes)-minute allowance")
        defer { pendingAllowance = nil }
        do {
            snapshot = try await service.updateAllowance(minutes: minutes)
            snapshot = try await service.reconcile()
            change = .idle
        } catch let failure as ServiceFailure {
            change = .failed(failure)
            await refreshSnapshot()
        } catch {
            change = .failed(.unexpected(error.localizedDescription))
        }
    }

    func disableRestrictions() async {
        change = .applying("Turning off restrictions")
        do {
            snapshot = try await service.disableRestrictions()
            change = .idle
        } catch let failure as ServiceFailure {
            change = .failed(failure)
            await refreshSnapshot()
        } catch {
            change = .failed(.unexpected(error.localizedDescription))
        }
    }

    func clearChange() { change = .idle }

    // MARK: Reward and release

    /// Records the credit once, then asks the systems layer to release the restriction.
    func completeReward(sessionID: UUID) async {
        guard !rewardInFlight.contains(sessionID) else { return }
        rewardInFlight.insert(sessionID)
        rewardFailure = nil
        defer { rewardInFlight.remove(sessionID) }
        do {
            snapshot = try await service.grantReward(sessionID: sessionID)
            snapshot = try await service.reconcile()
        } catch let failure as ServiceFailure {
            rewardFailure = failure
            await refreshSnapshot()
        } catch {
            rewardFailure = .unexpected(error.localizedDescription)
        }
    }

    /// Retries the pending platform operation. Never records another credit.
    func retryPendingOperation() async {
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        do {
            snapshot = try await service.retryPendingOperation()
            snapshot = try await service.reconcile()
        } catch let failure as ServiceFailure {
            rewardFailure = failure
            await refreshSnapshot()
        } catch {
            rewardFailure = .unexpected(error.localizedDescription)
        }
    }

    // MARK: Onboarding

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults?.set(true, forKey: Self.onboardingKey)
    }

    #if DEBUG
    func restartOnboarding() {
        hasCompletedOnboarding = false
        defaults?.set(false, forKey: Self.onboardingKey)
        profile = PreviewStudyProfile()
    }

    func applyFixture(_ fixture: DevelopmentFixture) async {
        guard let dev = service as? DevelopmentScreenTimeService else { return }
        dev.apply(fixture)
        authorizationRequest = .idle; selectionFlow = .idle; change = .idle; rewardFailure = nil
        await refreshSnapshot()
    }
    #endif
}
