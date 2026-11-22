import Foundation

public enum AuthorizationState: String, Codable, Equatable, Sendable {
    case notDetermined, approved, denied, revoked, unavailable
}

/// The domain receives counts and an opaque key. Token storage belongs to the platform adapter.
public struct ActivitySelection: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let applicationCount: Int
    public let categoryCount: Int
    public let webDomainCount: Int

    public init(id: UUID, applicationCount: Int, categoryCount: Int, webDomainCount: Int) {
        self.id = id
        self.applicationCount = applicationCount
        self.categoryCount = categoryCount
        self.webDomainCount = webDomainCount
    }

    var isValid: Bool {
        applicationCount >= 0 && categoryCount >= 0 && webDomainCount >= 0
            && (applicationCount > 0 || categoryCount > 0 || webDomainCount > 0)
    }
}

/// The generation identifies a single monitoring registration and fences stale callbacks.
public struct UsageCycle: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let thresholdMinutes: Int
    public let rewardSessionID: UUID?
}

public enum RestrictionState: Codable, Equatable, Sendable {
    case unconfigured
    case configuring
    case selectionRequired
    case available(UsageCycle)
    case applyingShield
    case restricted
    case practiceInProgress(sessionID: UUID)
    case rewardPending(sessionID: UUID)
    case authorizationUnavailable(AuthorizationState)
    case failed(RestrictionFailure)
}

public enum RestrictionFailure: String, Codable, Equatable, Sendable {
    case monitoring, shield, thresholdBeforeRelease
}

public enum LifecycleError: Error, Equatable, Sendable {
    case authorizationRequired(AuthorizationState)
    case invalidSelection
    case disabledPolicy
    case invalidTransition
    case configurationLocked
    case missingCredit
}

public enum DataProvenance: String, Equatable, Sendable {
    case observed, estimated, simulated
}

public enum DashboardValue<Value: Equatable & Sendable>: Equatable, Sendable {
    case available(Value, provenance: DataProvenance)
    case unavailable
}

public enum DashboardStatus: Equatable, Sendable {
    case loading
    case ready(DashboardSnapshot)
    case failed(PersistenceError)
}

/// A threshold is evidence that at least that much time accrued in a monitoring cycle.
/// Duration remaining is unavailable until a suitable source exists.
public struct DashboardSnapshot: Equatable, Sendable {
    public let authorization: AuthorizationState
    public let restriction: RestrictionState
    public let policy: ScreenTimePolicy
    public let selection: ActivitySelection?
    public let studyProfile: StudyProfile
    public let activeSession: PracticeSession?
    public let earnedMinutes: DashboardValue<Int>
    public let mostRecentThresholdMinutes: DashboardValue<Int>
    public let remainingMinutes: DashboardValue<Int>
    public let provenance: DataProvenance
}

public enum RestrictionEvent: Equatable, Sendable {
    case authorizationChanged(AuthorizationState)
    case monitoringInstalled(cycleID: UUID)
    case accessReleased(cycleID: UUID)
    case thresholdReached(cycleID: UUID)
    case shieldApplied(cycleID: UUID)
    case operationFailed(cycleID: UUID, RestrictionFailure)
    case retry(cycleID: UUID)
}

/// Operations carry their generation. Confirmation is a separate command after the adapter succeeds.
public enum RestrictionOperation: Equatable, Sendable {
    case installMonitoring(cycle: UsageCycle, selection: ActivitySelection)
    case releaseShield(cycleID: UUID)
    case applyShield(cycleID: UUID, selection: ActivitySelection)
}
