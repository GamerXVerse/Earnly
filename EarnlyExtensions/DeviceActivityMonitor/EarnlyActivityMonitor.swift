import DeviceActivity
import EarnlySystems
import Foundation
import OSLog

final class EarnlyActivityMonitor: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "EarnlySystems", category: "Monitor")

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        completeCallback { try $0.thresholdReached(activity: activity.rawValue, event: event.rawValue) }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        completeCallback { try $0.intervalEnded(activity: activity.rawValue) }
    }

    private func completeCallback(_ action: (AppleScreenTimeMonitorBridge) throws -> Void) {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "EarnlyAppGroupIdentifier") as? String,
              let host = Bundle.main.object(forInfoDictionaryKey: "EarnlyHostBundleIdentifier") as? String,
              !group.isEmpty, !host.isEmpty else {
            logger.error("Monitor configuration is missing")
            return
        }
        do {
            try action(AppleScreenTimeMonitorBridge(appGroupIdentifier: group, hostBundleIdentifier: host))
        } catch {
            logger.error("Monitor callback requires reconciliation")
        }
    }
}
