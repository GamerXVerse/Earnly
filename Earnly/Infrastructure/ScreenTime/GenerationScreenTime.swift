import Foundation

/// DeviceActivity operations run outside the file lock because callbacks can start during registration.
/// Shield writes run under the generation lock so a stale callback cannot race a release.
protocol ScreenTimeBackend: Sendable {
    func install(_ registration: MonitoringRegistration, selection: StoredActivitySelection) throws
    func contains(_ registration: MonitoringRegistration, selection: StoredActivitySelection) throws -> Bool
    func stopOthers(keeping name: String?) throws
    func apply(_ selection: StoredActivitySelection) throws
    func clear() throws
    func shieldStatus() -> ShieldStatus
}

struct GenerationScreenTime: Sendable {
    let journal: ScreenTimeJournal
    let backend: any ScreenTimeBackend
    let now: @Sendable () -> Date

    func prepareSelection(_ selection: StoredActivitySelection) throws {
        try journal.update { record in
            guard !record.retiring, record.registration == nil else { throw LifecycleError.configurationLocked }
            record.selection = selection
        }
    }

    func install(cycle: UsageCycle, selection: ActivitySelection) throws {
        let (registration, stored) = try journal.update { record in
            guard !record.retiring, let stored = record.selection, stored.summary == selection else {
                throw ScreenTimeServiceError.selectionNotFound
            }
            if let current = record.registration, current.cycleID == cycle.id {
                return (current, stored)
            }

            let start = now().addingTimeInterval(-120).roundedDownToSecond
            let registration = MonitoringRegistration(
                cycleID: cycle.id, selectionID: selection.id, minutes: cycle.thresholdMinutes,
                start: start, end: start.addingTimeInterval(24 * 60 * 60), timeZoneID: TimeZone.current.identifier
            )
            record.registration = registration
            return (registration, stored)
        }
        guard !registration.expired, now() < registration.end else { throw ScreenTimeServiceError.monitoringInterrupted }
        try backend.stopOthers(keeping: registration.name)
        if try !backend.contains(registration, selection: stored) {
            // If release might already have happened, reinstalling would reset an allowance in use.
            guard !registration.releaseRequested else { throw ScreenTimeServiceError.monitoringInterrupted }
            try backend.install(registration, selection: stored)
        }
        guard try backend.contains(registration, selection: stored) else {
            throw ScreenTimeServiceError.monitoringFailed
        }
    }

    func release(cycleID: UUID) throws {
        let snapshot = try journal.read()
        guard let registration = snapshot.registration, registration.cycleID == cycleID,
              let selection = snapshot.selection, !snapshot.retiring else { throw ScreenTimeServiceError.unknownCycle }
        // An already opened generation may have reached its threshold while the host was down.
        if registration.threshold != nil {
            if registration.releaseConfirmed { return }
            if registration.releaseRequested { throw ScreenTimeServiceError.monitoringInterrupted }
            throw ScreenTimeServiceError.earlyThreshold
        }
        guard !registration.expired, now() < registration.end,
              try backend.contains(registration, selection: selection) else {
            throw ScreenTimeServiceError.monitoringInterrupted
        }

        // Journal the intent before touching the store. A threshold in this gap will
        // interrupt release, preserving the credit while preventing an automatic reset.
        try journal.update { record in
            guard !record.retiring, var active = record.registration, active.cycleID == cycleID else {
                throw ScreenTimeServiceError.unknownCycle
            }
            if active.threshold != nil {
                if active.releaseConfirmed { return }
                if active.releaseRequested { throw ScreenTimeServiceError.monitoringInterrupted }
                throw ScreenTimeServiceError.earlyThreshold
            }
            guard !active.expired, now() < active.end else { throw ScreenTimeServiceError.monitoringInterrupted }
            active.releaseRequested = true
            record.registration = active
        }

        try journal.update { record in
            guard !record.retiring, var active = record.registration, active.cycleID == cycleID else {
                throw ScreenTimeServiceError.unknownCycle
            }
            if active.threshold != nil {
                guard active.releaseConfirmed else { throw ScreenTimeServiceError.monitoringInterrupted }
                return
            }
            guard !active.expired, now() < active.end else { throw ScreenTimeServiceError.monitoringInterrupted }
            try backend.clear()
            active.releaseConfirmed = true
            record.registration = active
        }
    }

    func apply(selection: ActivitySelection, cycleID: UUID) throws {
        try journal.update { record in
            guard !record.retiring, let stored = record.selection, stored.summary == selection else {
                throw ScreenTimeServiceError.selectionNotFound
            }
            // A renewed selection can need a shield before a registration is prepared.
            if let active = record.registration, active.cycleID != cycleID {
                throw ScreenTimeServiceError.unknownCycle
            }
            try backend.apply(stored)
        }
    }

    func threshold(activity: String, event: String, reachedAt: Date) throws {
        let cycleID = try journal.update { record -> UUID? in
            guard !record.retiring, var active = record.registration, !active.expired,
                  active.name == activity, active.eventName == event else { return nil }
            if active.threshold == nil {
                active.threshold = UsageThresholdEvent(cycleID: active.cycleID, reachedAt: reachedAt)
                record.registration = active
            }
            return active.cycleID
        }
        // Keep the receipt if the process dies or applying the store fails.
        if let cycleID { try reconcileThresholdShield(cycleID: cycleID) }
    }

    func reconcileThresholdShield(cycleID: UUID) throws {
        try journal.update { record in
            guard !record.retiring, let active = record.registration, active.cycleID == cycleID,
                  active.threshold != nil, let selection = record.selection else { return }
            try backend.apply(selection)
        }
    }

    func expire(activity: String) throws {
        let cycleID = try journal.update { record -> UUID? in
            guard !record.retiring, var active = record.registration, active.name == activity,
                  active.threshold == nil else { return nil }
            active.expired = true
            record.registration = active
            return active.cycleID
        }
        if let cycleID { try reconcileExpiredShield(cycleID: cycleID) }
    }

    func reconcileExpiredShield(cycleID: UUID) throws {
        try journal.update { record in
            guard !record.retiring, let active = record.registration, active.cycleID == cycleID,
                  active.expired, let selection = record.selection else { return }
            try backend.apply(selection)
        }
    }

    func acknowledge(cycleID: UUID) throws {
        try journal.update { record in
            guard var active = record.registration, active.cycleID == cycleID, active.threshold != nil else { return }
            active.thresholdAcknowledged = true
            record.registration = active
        }
    }

    /// Fence callbacks before stopping registrations. Retain the marker until both effects succeed.
    func retire(clearSelection: Bool, leaveFence: Bool = false) throws {
        do {
            try journal.update { $0.retiring = true }
        } catch let error as ScreenTimePersistenceError {
            // A corrupt or unknown record is already unreadable to callbacks. Clear our store
            // even so, preserving the original bytes and keeping reconfiguration blocked.
            switch error {
            case .corrupt, .unsupportedVersion:
                try stopAndClear()
                return
            default: throw error
            }
        }
        try stopAndClear()
        if !leaveFence { try finishRetirement(clearSelection: clearSelection) }
    }

    func finishRetirement(clearSelection: Bool) throws {
        try journal.update { record in
            record.registration = nil
            if clearSelection { record.selection = nil }
            record.retiring = false
        }
    }

    private func stopAndClear() throws {
        do {
            try backend.stopOthers(keeping: nil)
        } catch {
            // Try clearing even if stopping failed. A durable retirement marker fences callbacks.
            try journal.exclusive { try backend.clear() }
            throw error
        }
        try journal.exclusive { try backend.clear() }
    }
}

private extension Date {
    var roundedDownToSecond: Date {
        Date(timeIntervalSince1970: timeIntervalSince1970.rounded(.down))
    }
}
