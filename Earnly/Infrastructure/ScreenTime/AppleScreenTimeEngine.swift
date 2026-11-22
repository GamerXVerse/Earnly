#if os(iOS) && !targetEnvironment(macCatalyst)
import FamilyControls
import Foundation

/// Main-actor entry point for the host and the system picker. Platform effects are serialized
/// by the coordinator. Use a private host URL for learning history and the registered App Group
/// for the Screen Time journal.
@MainActor
public final class AppleScreenTimeEngine {
    public let system: EarnlySystem
    private let backend: AppleScreenTimeBackend
    private let coordinator: ScreenTimeCoordinator
    private let journal: ScreenTimeJournal

    public init(fileURL: URL, appGroupIdentifier: String, hostBundleIdentifier: String) throws {
        guard Bundle.main.bundleIdentifier == hostBundleIdentifier, !hostBundleIdentifier.isEmpty else {
            throw ScreenTimeServiceError.invalidHostConfiguration
        }
        let journal = try AppleScreenTimeContainer.journal(group: appGroupIdentifier)
        let backend = AppleScreenTimeBackend(hostBundleIdentifier: hostBundleIdentifier)
        let system = try EarnlySystem(fileURL: fileURL, provenance: .observed)
        self.system = system
        self.backend = backend
        self.journal = journal
        coordinator = ScreenTimeCoordinator(
            system: system, authorization: AppleIndividualAuthorization(),
            platform: GenerationScreenTime(journal: journal, backend: backend, now: Date.init)
        )
    }

    public func dashboard() async -> NativeDashboard { await coordinator.dashboard() }

    @discardableResult
    public func requestAuthorization() async throws -> AuthorizationState {
        try await coordinator.requestAuthorization()
    }

    public func appDidBecomeActive() async throws { try await coordinator.activate() }

    /// Read a draft for FamilyActivityPicker. A cancelled draft never reaches configure.
    public func pickerSelection() throws -> FamilyActivitySelection {
        guard let record = try journal.read().selection else { return FamilyActivitySelection() }
        return try backend.selection(from: record)
    }

    public func configure(policy: ScreenTimePolicy, selection: FamilyActivitySelection) async throws {
        guard #available(iOS 17.4, *) else { throw ScreenTimeServiceError.unsupportedOS }
        let stored = try backend.selectionRecord(selection)
        try await coordinator.configure(policy: policy, selection: stored)
    }

    @discardableResult
    public func finishPractice(sessionID: UUID) async throws -> RewardTransaction {
        try await coordinator.finishPractice(sessionID: sessionID)
    }

    public func retry() async throws { try await coordinator.retry() }
    public func disable() async throws { try await coordinator.disable() }
}

enum AppleScreenTimeContainer {
    static func journal(group: String) throws -> ScreenTimeJournal {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw ScreenTimePersistenceError.containerUnavailable
        }
        return ScreenTimeJournal(directory: container.appendingPathComponent("EarnlyScreenTime", isDirectory: true))
    }
}

/// Synchronous entry points keep extension work within the framework callback lifetime.
public struct AppleScreenTimeMonitorBridge: Sendable {
    private let platform: GenerationScreenTime

    public init(appGroupIdentifier: String, hostBundleIdentifier: String) throws {
        platform = GenerationScreenTime(
            journal: try AppleScreenTimeContainer.journal(group: appGroupIdentifier),
            backend: AppleScreenTimeBackend(hostBundleIdentifier: hostBundleIdentifier), now: Date.init
        )
    }

    public func thresholdReached(activity: String, event: String) throws {
        guard AppleScreenTimeBackend.hasAuthorization else { return }
        try platform.threshold(activity: activity, event: event, reachedAt: Date())
    }

    public func intervalEnded(activity: String) throws {
        guard AppleScreenTimeBackend.hasAuthorization else { return }
        try platform.expire(activity: activity)
    }
}
#endif
