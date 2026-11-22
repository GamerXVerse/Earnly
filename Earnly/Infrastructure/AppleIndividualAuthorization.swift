#if os(iOS) && !targetEnvironment(macCatalyst)
import FamilyControls
import OSLog

/// Optional feasibility adapter. Instantiate only in a build signed for Family Controls.
/// Standard individual authorization is sufficient for the opaque-token workflow.
@MainActor
public final class AppleIndividualAuthorization: ScreenTimeAuthorizing {
    private static let logger = Logger(subsystem: "EarnlySystems", category: "ScreenTime")
    private var wasApproved = false

    public init() {}

    public func authorizationState() -> AuthorizationState {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved, .approvedWithDataAccess:
            wasApproved = true
            return .approved
        case .denied:
            return wasApproved ? .revoked : .denied
        case .notDetermined:
            return wasApproved ? .revoked : .notDetermined
        @unknown default:
            return .unavailable
        }
    }

    public func requestAuthorization() async throws -> AuthorizationState {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            Self.logger.notice("Family Controls authorization request failed")
            switch authorizationState() {
            case .denied: throw ScreenTimeServiceError.denied
            case .revoked: throw ScreenTimeServiceError.revoked
            default: throw ScreenTimeServiceError.requestFailed
            }
        }
        switch authorizationState() {
        case .approved: return .approved
        case .denied: throw ScreenTimeServiceError.denied
        case .revoked: throw ScreenTimeServiceError.revoked
        case .notDetermined, .unavailable: throw ScreenTimeServiceError.unavailable
        }
    }
}
#endif
