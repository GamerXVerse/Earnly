import Foundation

/// An in-memory adapter driven by explicit events. No timers, OS access, or entitlements.
public actor SimulatedScreenTime: ScreenTimeAuthorizing, ActivitySelectionProviding,
    RestrictionControlling, UsageMonitoring {
    public enum Operation: Hashable, Sendable { case authorization, monitoring, shield }

    private var authorization: AuthorizationState
    private var selection: ActivitySelection?
    private var installedCycleID: UUID?
    private var mostRecentCycleID: UUID?
    private var shield: ShieldStatus = .clear
    private var failures: Set<Operation> = []
    private var subscribers: [UUID: AsyncStream<UsageThresholdEvent>.Continuation] = [:]

    public init(authorization: AuthorizationState = .notDetermined) {
        self.authorization = authorization
    }

    public func setAuthorization(_ state: AuthorizationState) {
        authorization = state
        if state != .approved {
            selection = nil
            installedCycleID = nil
            mostRecentCycleID = nil
            shield = .clear
        }
    }

    public func failNext(_ operation: Operation) {
        failures.insert(operation)
    }

    public func authorizationState() -> AuthorizationState { authorization }

    public func requestAuthorization() throws -> AuthorizationState {
        if failures.remove(.authorization) != nil { throw ScreenTimeServiceError.requestFailed }
        switch authorization {
        case .notDetermined, .approved:
            authorization = .approved
            return .approved
        case .denied: throw ScreenTimeServiceError.denied
        case .revoked: throw ScreenTimeServiceError.revoked
        case .unavailable: throw ScreenTimeServiceError.unavailable
        }
    }

    public func loadSelection() -> ActivitySelection? { selection }

    public func saveSelection(_ selection: ActivitySelection) throws {
        try checkAuthorization()
        guard selection.isValid else { throw ScreenTimeServiceError.invalidSelection }
        self.selection = selection
    }

    public func clearSelection() { selection = nil }

    public func installMonitoring(for cycle: UsageCycle, selection: ActivitySelection) throws {
        try checkAuthorization()
        guard selection == self.selection else { throw ScreenTimeServiceError.selectionNotFound }
        if failures.remove(.monitoring) != nil { throw ScreenTimeServiceError.monitoringFailed }
        installedCycleID = cycle.id
        mostRecentCycleID = cycle.id
    }

    public func stopMonitoring(cycleID: UUID) {
        if installedCycleID == cycleID { installedCycleID = nil }
    }

    public func applyShield(for selection: ActivitySelection, cycleID: UUID) throws {
        try checkAuthorization()
        if let installedCycleID, cycleID != installedCycleID { throw ScreenTimeServiceError.unknownCycle }
        guard selection == self.selection else { throw ScreenTimeServiceError.selectionNotFound }
        if failures.remove(.shield) != nil { throw ScreenTimeServiceError.shieldingFailed }
        mostRecentCycleID = cycleID
        shield = .applied
    }

    public func removeShield(cycleID: UUID) throws {
        try checkAuthorization()
        guard cycleID == mostRecentCycleID else { throw ScreenTimeServiceError.unknownCycle }
        if failures.remove(.shield) != nil { throw ScreenTimeServiceError.shieldingFailed }
        shield = .clear
    }

    public func reconcileShield() -> ShieldStatus { authorization == .approved ? shield : .unavailable }

    public func thresholdEvents() -> AsyncStream<UsageThresholdEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<UsageThresholdEvent>.makeStream()
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    /// The caller supplies the evidence and its timestamp. Repeated callbacks can be exercised.
    public func emitThreshold(_ event: UsageThresholdEvent) throws {
        try checkAuthorization()
        guard event.cycleID == installedCycleID else { throw ScreenTimeServiceError.unknownCycle }
        for subscriber in subscribers.values { subscriber.yield(event) }
    }

    private func removeSubscriber(_ id: UUID) { subscribers[id] = nil }

    private func checkAuthorization() throws {
        switch authorization {
        case .approved: return
        case .denied: throw ScreenTimeServiceError.denied
        case .revoked: throw ScreenTimeServiceError.revoked
        case .notDetermined, .unavailable: throw ScreenTimeServiceError.unavailable
        }
    }
}
