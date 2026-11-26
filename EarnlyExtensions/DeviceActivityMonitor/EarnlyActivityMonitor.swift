import DeviceActivity
import EarnlySystems
import Foundation
import OSLog
import UserNotifications

final class EarnlyActivityMonitor: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "EarnlySystems", category: "Monitor")

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        completeCallback {
            if try $0.thresholdReached(activity: activity.rawValue, event: event.rawValue) {
                logger.notice("Reached the current allowance threshold")
            }
        }
        let warningID = notificationID(for: activity)
        let notifications = UNUserNotificationCenter.current()
        notifications.removePendingNotificationRequests(withIdentifiers: [warningID])
        notifications.removeDeliveredNotifications(withIdentifiers: [warningID])
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        completeCallback { bridge in
            guard let seconds = try bridge.claimThresholdWarning(activity: activity.rawValue, event: event.rawValue)
            else { return }

            let content = UNMutableNotificationContent()
            content.title = "Earnly allowance almost used"
            let time = Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
            content.body = "About \(time) of selected app use remained at the warning. Open Earnly after your apps lock."
            let request = UNNotificationRequest(identifier: notificationID(for: activity), content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { [logger] error in
                if error != nil { logger.debug("Allowance warning was not delivered") }
            }
        }
    }

    private func notificationID(for activity: DeviceActivityName) -> String { activity.rawValue + ".warning" }

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
