import Darwin
import Foundation

public enum ScreenTimePersistenceError: Error, Equatable, Sendable {
    case containerUnavailable, busy, unreadable, corrupt, unsupportedVersion(Int), writeFailed
}

struct StoredActivitySelection: Codable, Equatable, Sendable {
    let summary: ActivitySelection
    let opaqueSelection: Data
}

/// The shield extension learns this only from a callback for Earnly itself.
struct HostShieldExclusion: Codable, Equatable, Sendable {
    let selectionID: UUID
    let opaqueToken: Data?

    func applicationsToShield<Token: Hashable>(
        _ selected: Set<Token>, selectionID: UUID, decode: (Data) throws -> Token
    ) throws -> Set<Token> {
        if let opaqueToken {
            return selected.subtracting([try decode(opaqueToken)])
        }
        // If the system identifies Earnly but omits its token, suspend app shields
        // for the affected selection. A new selection can still shield apps.
        return self.selectionID == selectionID ? [] : selected
    }
}

struct MonitoringRegistration: Codable, Equatable, Sendable {
    let cycleID: UUID
    let selectionID: UUID
    let minutes: Int
    let start: Date
    let end: Date
    let timeZoneID: String
    var releaseRequested = false
    var releaseConfirmed = false
    var threshold: UsageThresholdEvent?
    var thresholdAcknowledged = false
    var expired = false

    static let namespace = "earnly.allowance."
    var name: String { Self.namespace + cycleID.uuidString }
    var eventName: String { name + ".threshold" }
}

struct ScreenTimeRecord: Codable, Equatable, Sendable {
    static let currentVersion = 1
    var version = Self.currentVersion
    var selection: StoredActivitySelection?
    var registration: MonitoringRegistration?
    var retiring = false
    var hostShieldExclusion: HostShieldExclusion?

    var isValid: Bool {
        guard selection?.summary.isValid != false, selection?.opaqueSelection.isEmpty != true else { return false }
        guard let registration else { return true }
        return registration.selectionID == selection?.summary.id && registration.minutes > 0
            && registration.end.timeIntervalSince(registration.start) >= 15 * 60
            && TimeZone(identifier: registration.timeZoneID) != nil
            && (registration.threshold.map { $0.cycleID == registration.cycleID } ?? true)
            && (!registration.releaseConfirmed || registration.releaseRequested)
            && (!registration.thresholdAcknowledged || registration.threshold != nil)
    }
}

/// A permanent lock inode serializes host and extension read-modify-write operations.
/// Atomic replacement protects the journal itself if a writer is terminated.
struct ScreenTimeJournal: Sendable {
    private struct Header: Decodable { let version: Int }
    let directory: URL

    private var file: URL { directory.appendingPathComponent("screen-time.json") }
    private var lockFile: URL { directory.appendingPathComponent("screen-time.lock") }

    func read() throws -> ScreenTimeRecord {
        try exclusive { try load() }
    }

    @discardableResult
    func update<Value>(_ body: (inout ScreenTimeRecord) throws -> Value) throws -> Value {
        try exclusive {
            let original = try load()
            var record = original
            let result = try body(&record)
            if record != original { try save(record) }
            return result
        }
    }

    /// Available to the disable path even when the journal cannot be decoded.
    func exclusive<Value>(_ action: () throws -> Value) throws -> Value {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw ScreenTimePersistenceError.containerUnavailable
        }
        let descriptor = open(lockFile.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw ScreenTimePersistenceError.unreadable }
        defer { close(descriptor) }

        // Bound the wait in extensions. The kernel releases this lock if a process dies.
        let deadline = ContinuousClock.now + .milliseconds(250)
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EINTR else { throw ScreenTimePersistenceError.unreadable }
            guard ContinuousClock.now < deadline else { throw ScreenTimePersistenceError.busy }
            usleep(5_000)
        }
        defer { flock(descriptor, LOCK_UN) }
        return try action()
    }

    private func load() throws -> ScreenTimeRecord {
        let bytes: Data
        do {
            bytes = try Data(contentsOf: file)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return ScreenTimeRecord()
        } catch {
            throw ScreenTimePersistenceError.unreadable
        }

        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: bytes) else {
            throw ScreenTimePersistenceError.corrupt
        }
        guard header.version == ScreenTimeRecord.currentVersion else {
            throw ScreenTimePersistenceError.unsupportedVersion(header.version)
        }
        guard let record = try? decoder.decode(ScreenTimeRecord.self, from: bytes), record.isValid else {
            throw ScreenTimePersistenceError.corrupt
        }
        return record
    }

    private func save(_ record: ScreenTimeRecord) throws {
        guard record.isValid else { throw ScreenTimePersistenceError.corrupt }
        do {
            #if os(iOS)
            try JSONEncoder().encode(record).write(
                to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            #else
            try JSONEncoder().encode(record).write(to: file, options: .atomic)
            #endif
        } catch {
            throw ScreenTimePersistenceError.writeFailed
        }
    }
}
