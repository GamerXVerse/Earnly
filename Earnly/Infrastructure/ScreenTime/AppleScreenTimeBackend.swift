#if os(iOS) && !targetEnvironment(macCatalyst)
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import OSLog

struct AppleScreenTimeBackend: ScreenTimeBackend {
    let hostBundleIdentifier: String
    private static let logger = Logger(subsystem: "EarnlySystems", category: "DeviceActivity")

    private struct OpaqueTokens: Codable {
        let applications: Set<ApplicationToken>
        let webDomains: Set<WebDomainToken>
    }

    private var store: ManagedSettingsStore { ManagedSettingsStore(named: .init("earnly.entertainment")) }

    func selectionRecord(_ selection: FamilyActivitySelection, excludingHost: HostShieldExclusion?) throws
        -> StoredActivitySelection {
        var safe = selection
        guard safe.categoryTokens.isEmpty else { throw ScreenTimeServiceError.unsafeSelection }
        if let token = Self.hostToken(from: excludingHost) ?? Application(bundleIdentifier: hostBundleIdentifier).token {
            safe.applicationTokens.remove(token)
        }
        guard !safe.applicationTokens.isEmpty || !safe.webDomainTokens.isEmpty else {
            throw ScreenTimeServiceError.invalidSelection
        }
        let summary = ActivitySelection(
            id: UUID(), applicationCount: safe.applicationTokens.count,
            categoryCount: safe.categoryTokens.count, webDomainCount: safe.webDomainTokens.count
        )
        let tokens = OpaqueTokens(applications: safe.applicationTokens, webDomains: safe.webDomainTokens)
        return StoredActivitySelection(summary: summary, opaqueSelection: try JSONEncoder().encode(tokens))
    }

    func selection(from record: StoredActivitySelection) throws -> FamilyActivitySelection {
        guard let tokens = try? JSONDecoder().decode(OpaqueTokens.self, from: record.opaqueSelection),
              tokens.applications.count == record.summary.applicationCount,
              record.summary.categoryCount == 0, tokens.webDomains.count == record.summary.webDomainCount else {
            throw ScreenTimePersistenceError.corrupt
        }
        var selection = FamilyActivitySelection()
        selection.applicationTokens = tokens.applications
        selection.webDomainTokens = tokens.webDomains
        return selection
    }

    static func hostToken(from exclusion: HostShieldExclusion?) -> ApplicationToken? {
        guard let data = exclusion?.opaqueToken else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    /// The shield callback can identify Earnly by its bundle ID. Remember its token
    /// when provided, then remove the shield without allowing the monitor to reapply it.
    func recoverHostShield(for application: Application, journal: ScreenTimeJournal?) -> Bool {
        guard application.bundleIdentifier == hostBundleIdentifier else { return false }

        let token = application.token
        if let journal {
            do {
                try journal.update { record in
                    if let selection = record.selection, !record.retiring {
                        record.hostShieldExclusion = HostShieldExclusion(
                            selectionID: selection.summary.id, opaqueToken: try token.map { try JSONEncoder().encode($0) }
                        )
                    }
                    removeHostShield(token)
                }
                return true
            } catch {
                Self.logger.error("Could not record Earnly shield recovery")
            }
        }
        // Restoring access to Earnly also works if the shared container is temporarily unavailable.
        removeHostShield(token)
        return true
    }

    private func removeHostShield(_ token: ApplicationToken?) {
        let store = store
        guard let current = store.shield.applications else { return }
        let remaining = token.map { current.subtracting([$0]) } ?? []
        store.shield.applications = remaining.isEmpty ? nil : remaining
    }

    func install(_ registration: MonitoringRegistration, selection: StoredActivitySelection) throws {
        let selection = try self.selection(from: selection)
        let schedule = monitorSchedule(registration)
        guard let interval = schedule.nextInterval, interval.start == registration.start,
              interval.end == registration.end else {
            Self.logger.error("Calendar interval differs from the prepared window")
            throw ScreenTimeServiceError.monitoringFailed
        }
        let event = try monitorEvent(registration, selection: selection)
        do {
            try DeviceActivityCenter().startMonitoring(
                .init(registration.name), during: schedule, events: [.init(registration.eventName): event]
            )
        } catch let error as DeviceActivityCenter.MonitoringError {
            let reason: String
            switch error {
            case .excessiveActivities: reason = "registration limit"
            case .intervalTooLong: reason = "interval too long"
            case .intervalTooShort: reason = "interval too short"
            case .invalidDateComponents: reason = "invalid calendar components"
            case .unauthorized: reason = "authorization missing"
            @unknown default: reason = "unknown rejection"
            }
            Self.logger.error("Registration rejected: \(reason, privacy: .public)")
            throw ScreenTimeServiceError.monitoringFailed
        } catch {
            Self.logger.error("Unexpected registration error")
            throw ScreenTimeServiceError.monitoringFailed
        }
    }

    func contains(_ registration: MonitoringRegistration, selection: StoredActivitySelection) throws -> Bool {
        let center = DeviceActivityCenter()
        let name = DeviceActivityName(registration.name)
        guard center.activities.contains(name), let schedule = center.schedule(for: name),
              let interval = schedule.nextInterval, interval.start == registration.start,
              interval.end == registration.end, !schedule.repeats else { return false }
        let event = try monitorEvent(registration, selection: self.selection(from: selection))
        return center.events(for: name) == [.init(registration.eventName): event]
    }

    func stopOthers(keeping name: String?) throws {
        let center = DeviceActivityCenter()
        let obsolete = center.activities.filter {
            $0.rawValue.hasPrefix(MonitoringRegistration.namespace) && $0.rawValue != name
        }
        guard !obsolete.isEmpty else { return }
        center.stopMonitoring(obsolete)
        guard !center.activities.contains(where: obsolete.contains) else { throw ScreenTimeServiceError.monitoringFailed }
    }

    func apply(_ record: StoredActivitySelection, excludingHost: HostShieldExclusion?) throws {
        let selection = try selection(from: record)
        var allowed = selection.applicationTokens
        if let excludingHost {
            allowed = try excludingHost.applicationsToShield(allowed, selectionID: record.summary.id) {
                try JSONDecoder().decode(ApplicationToken.self, from: $0)
            }
        }
        if let token = Application(bundleIdentifier: hostBundleIdentifier).token {
            allowed.remove(token)
        }
        let apps = allowed.isEmpty ? nil : allowed
        let web = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        let store = store
        store.shield.applications = apps
        store.shield.webDomains = web
        guard store.shield.applications == apps, store.shield.webDomains == web else {
            throw ScreenTimeServiceError.shieldingFailed
        }
    }

    func clear() throws {
        store.clearAllSettings()
        guard shieldStatus() == .clear else { throw ScreenTimeServiceError.shieldingFailed }
    }

    func shieldStatus() -> ShieldStatus {
        let shield = store.shield
        let apps: ShieldSettings.ActivityCategoryPolicy<Application> = shield.applicationCategories ?? .none
        let web: ShieldSettings.ActivityCategoryPolicy<WebDomain> = shield.webDomainCategories ?? .none
        if shield.applications?.isEmpty == false || shield.webDomains?.isEmpty == false
            || apps != .none || web != .none {
            return .applied
        }
        return .clear
    }

    private func monitorEvent(_ registration: MonitoringRegistration, selection: FamilyActivitySelection) throws
        -> DeviceActivityEvent {
        guard #available(iOS 17.4, *) else { throw ScreenTimeServiceError.unsupportedOS }
        return DeviceActivityEvent(
            applications: selection.applicationTokens, categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens, threshold: .init(minute: registration.minutes),
            includesPastActivity: false
        )
    }

    private func monitorSchedule(_ registration: MonitoringRegistration) -> DeviceActivitySchedule {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: registration.timeZoneID) ?? .gmt
        let fields: Set<Calendar.Component> = [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second]
        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: registration.start),
            intervalEnd: calendar.dateComponents(fields, from: registration.end),
            repeats: false
        )
    }
}
#endif
