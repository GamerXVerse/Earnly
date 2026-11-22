import Foundation
import OSLog

public enum PersistenceError: Error, Equatable, Sendable {
    case unreadable
    case corrupt
    case unsupportedVersion(Int)
    case invalidState
    case writeFailed
}

struct LocalStateFile: Sendable {
    private struct Header: Decodable { let version: Int }
    private static let logger = Logger(subsystem: "EarnlySystems", category: "Persistence")
    let url: URL

    func load() throws -> LocalState {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return LocalState()
        } catch {
            Self.logger.error("Could not read local state")
            throw PersistenceError.unreadable
        }
        let decoder = JSONDecoder()
        let state: LocalState
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.version == LocalState.currentVersion else {
                throw PersistenceError.unsupportedVersion(header.version)
            }
            state = try decoder.decode(LocalState.self, from: data)
        } catch let error as PersistenceError {
            throw error
        } catch {
            Self.logger.error("Could not decode local state")
            throw PersistenceError.corrupt
        }
        guard state.isValid else {
            Self.logger.error("Local state violated an invariant")
            throw PersistenceError.invalidState
        }
        return state
    }

    func save(_ state: LocalState) throws {
        do {
            let parent = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            #if os(iOS)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: url, options: .atomic)
            #endif
        } catch {
            Self.logger.error("Could not commit local state")
            throw PersistenceError.writeFailed
        }
    }
}
