import Foundation

/// One honest sentence about whether monitoring is running, derived only from the snapshot.
struct MonitoringStatus: Equatable {
    enum Kind: Equatable { case on, pending, off, failed }
    let kind: Kind
    let text: String

    static func make(from snapshot: ServiceSnapshot?) -> MonitoringStatus {
        guard let s = snapshot else { return .init(kind: .pending, text: "Checking monitoring status") }
        guard s.authorization == .approved else { return .init(kind: .off, text: "Not monitoring. Screen Time access is off.") }
        guard let selection = s.selection, !selection.isEmpty else {
            return .init(kind: .off, text: "Not monitoring. No apps are chosen.")
        }
        switch s.stage {
        case .unconfigured, .selectionRequired, .authorizationUnavailable:
            return .init(kind: .off, text: "Not monitoring. Choose your apps again.")
        case .configuring: return .init(kind: .pending, text: "Setting up monitoring")
        case .applyingShield: return .init(kind: .pending, text: "Applying restriction")
        case .failed(.shield): return .init(kind: .failed, text: "Couldn't update restrictions")
        case .failed: return .init(kind: .failed, text: "Monitoring failed to start")
        case .available, .restricted, .practiceInProgress, .rewardPending:
            return .init(kind: .on, text: "Monitoring is on")
        }
    }
}

extension AppModel {
    var monitoringStatus: MonitoringStatus { .make(from: snapshot) }
}
