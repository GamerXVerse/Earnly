import Foundation

public enum ScreenTimeServiceError: Error, Equatable, Sendable {
    case denied, revoked, unavailable, requestFailed, invalidSelection, selectionNotFound
    case monitoringFailed, shieldingFailed, unknownCycle
}

public protocol ScreenTimeAuthorizing: Sendable {
    func authorizationState() async -> AuthorizationState
    func requestAuthorization() async throws -> AuthorizationState
}

/// The platform implementation owns private tokens. Consumers use summaries and local IDs.
public protocol ActivitySelectionProviding: Sendable {
    func loadSelection() async throws -> ActivitySelection?
    func saveSelection(_ selection: ActivitySelection) async throws
    func clearSelection() async throws
}

public enum ShieldStatus: Equatable, Sendable {
    case applied, clear, unavailable
}

public protocol RestrictionControlling: Sendable {
    func applyShield(for selection: ActivitySelection, cycleID: UUID) async throws
    func removeShield(cycleID: UUID) async throws
    func reconcileShield() async throws -> ShieldStatus
}

public struct UsageThresholdEvent: Codable, Equatable, Sendable {
    public let cycleID: UUID
    public let reachedAt: Date

    public init(cycleID: UUID, reachedAt: Date) {
        self.cycleID = cycleID
        self.reachedAt = reachedAt
    }
}

public protocol UsageMonitoring: Sendable {
    func installMonitoring(for cycle: UsageCycle, selection: ActivitySelection) async throws
    func stopMonitoring(cycleID: UUID) async throws
    /// Development uses an in-process stream. A device adapter can replay durable extension events.
    func thresholdEvents() async -> AsyncStream<UsageThresholdEvent>
}

public protocol QuestionProviding: Sendable {
    func questions(for profile: StudyProfile, count: Int) throws -> [EarnlyQuestion]
}

public protocol PracticeSessionManaging: Sendable {
    func startPractice() async throws -> PracticeSession
    func session(id: UUID) async throws -> PracticeSession
    func submitAnswer(sessionID: UUID, questionID: String, answerID: String) async throws -> PracticeSession
}

public protocol RewardManaging: Sendable {
    func grantReward(for sessionID: UUID) async throws -> RewardTransaction
    func rewardLedger() async -> RewardLedger
}

public protocol ProfilePersisting: Sendable {
    func studyProfile() async -> StudyProfile
    func saveStudyProfile(_ profile: StudyProfile) async throws
}

/// Phase 2 implements a cross-process, selection-token-free threshold inbox.
/// A receipt may be acknowledged only after its corresponding state transaction commits.
public protocol SharedThresholdInbox: Sendable {
    func appendThreshold(_ event: UsageThresholdEvent) async throws
    func pendingThresholds() async throws -> [UsageThresholdEvent]
    func acknowledgeThreshold(cycleID: UUID) async throws
}
