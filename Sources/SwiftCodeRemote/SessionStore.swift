/// Persistent session store for background Claude Code sessions.
///
/// Sessions are written as JSON files to ~/.claude/sessions/
/// (or a custom directory for testing).

import Foundation

// MARK: - SessionStore

/// Actor-isolated store for BackgroundSession records on disk.
public actor SessionStore {

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: Init

    public init(directory: URL) {
        self.directory = directory
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    public init() {
        self.init(directory: SessionStore.defaultDirectory())
    }

    // MARK: Default Directory

    public static func defaultDirectory() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/sessions")
    }

    // MARK: CRUD

    /// Add a new session record to disk.
    public func add(_ session: BackgroundSession) async throws {
        try ensureDirectory()
        let path = filePath(for: session.id)
        let data = try encoder.encode(session)
        try data.write(to: path, options: .atomic)
    }

    /// Update an existing session record.
    public func update(_ session: BackgroundSession) async throws {
        try await add(session)  // overwrite
    }

    /// Get a session by ID.
    public func get(id: UUID) async throws -> BackgroundSession? {
        let path = filePath(for: id)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        let data = try Data(contentsOf: path)
        return try decoder.decode(BackgroundSession.self, from: data)
    }

    /// Remove a session record from disk.
    public func remove(id: UUID) async throws {
        let path = filePath(for: id)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }

    /// List all session records.
    public func list() async throws -> [BackgroundSession] {
        try ensureDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        return jsonFiles.compactMap { file in
            guard let data = try? Data(contentsOf: file) else { return nil }
            return try? decoder.decode(BackgroundSession.self, from: data)
        }.sorted { $0.startedAt < $1.startedAt }
    }

    /// Remove all session records.
    public func removeAll() async throws {
        let sessions = try await list()
        for session in sessions {
            try await remove(id: session.id)
        }
    }

    // MARK: Helpers

    private func filePath(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }
}
