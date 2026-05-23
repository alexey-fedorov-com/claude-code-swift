/// SessionMemory — in-session memory log.
///
/// Stores key-value observations associated with a session ID.
/// Mirrors the session memory store in `src/services/memory/`.

import Foundation

// MARK: - MemoryEntry

public struct MemoryEntry: Codable, Equatable, Sendable {
    public let id: String
    public let sessionID: String
    public let key: String
    public let value: String
    public let createdAt: Date

    public init(id: String = UUID().uuidString, sessionID: String, key: String, value: String, createdAt: Date = Date()) {
        self.id = id
        self.sessionID = sessionID
        self.key = key
        self.value = value
        self.createdAt = createdAt
    }
}

// MARK: - SessionMemory

public actor SessionMemory {
    private var store: [String: [MemoryEntry]] = [:]   // keyed by sessionID

    public init() {}

    // MARK: - Write

    /// Add an entry to the session memory log.
    public func add(_ entry: MemoryEntry) {
        store[entry.sessionID, default: []].append(entry)
    }

    /// Record a key-value pair for the given session.
    @discardableResult
    public func record(sessionID: String, key: String, value: String) -> MemoryEntry {
        let entry = MemoryEntry(sessionID: sessionID, key: key, value: value)
        add(entry)
        return entry
    }

    // MARK: - Read

    /// All entries for the given session, in insertion order.
    public func entries(for sessionID: String) -> [MemoryEntry] {
        store[sessionID] ?? []
    }

    /// Look up the latest entry for a key within a session.
    public func latest(for key: String, sessionID: String) -> MemoryEntry? {
        store[sessionID]?.last { $0.key == key }
    }

    /// All entries across all sessions.
    public func allEntries() -> [MemoryEntry] {
        store.values.flatMap { $0 }.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Clear

    public func clear(sessionID: String) {
        store[sessionID] = nil
    }

    public func clearAll() {
        store.removeAll()
    }
}
