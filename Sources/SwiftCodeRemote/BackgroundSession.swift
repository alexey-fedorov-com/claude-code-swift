/// Background session types and management.
///
/// When launched with `--bg/--background`, Claude Code runs a session in the
/// background, tracked by PID and log path. Sessions can be listed, attached,
/// and killed via `claude sessions` subcommands.

import Foundation

// MARK: - BackgroundSession

/// Represents a running (or recently exited) background Claude Code session.
public struct BackgroundSession: Codable, Sendable, Identifiable {
    public let id: UUID
    public let pid: Int32
    public let startedAt: Date
    public let command: String
    public let logPath: URL
    public var exitCode: Int32?
    public var exitedAt: Date?

    public init(
        id: UUID = UUID(),
        pid: Int32,
        startedAt: Date = Date(),
        command: String,
        logPath: URL,
        exitCode: Int32? = nil,
        exitedAt: Date? = nil
    ) {
        self.id = id
        self.pid = pid
        self.startedAt = startedAt
        self.command = command
        self.logPath = logPath
        self.exitCode = exitCode
        self.exitedAt = exitedAt
    }

    /// Whether the session process is still running.
    public var isRunning: Bool {
        guard exitCode == nil else { return false }
        // kill(pid, 0) returns 0 if process exists
        return kill(pid, 0) == 0
    }

    /// Elapsed time since the session started.
    public var elapsed: TimeInterval {
        (exitedAt ?? Date()).timeIntervalSince(startedAt)
    }
}

// MARK: - BackgroundSessionError

public enum BackgroundSessionError: Error, Sendable {
    case sessionNotFound(UUID)
    case processNotRunning(UUID)
    case killFailed(Int32)
    case logNotAvailable(URL)
}

// MARK: - BackgroundSessionManager

/// Launch and manage background sessions.
public actor BackgroundSessionManager {

    private let store: SessionStore
    private let executablePath: String

    public init(store: SessionStore, executablePath: String = ProcessInfo.processInfo.arguments[0]) {
        self.store = store
        self.executablePath = executablePath
    }

    /// Launch a new background session with the given arguments.
    ///
    /// - Parameter args: CLI arguments to pass (e.g. ["--print", "your prompt"]).
    /// - Returns: The newly created `BackgroundSession`.
    public func launch(args: [String]) async throws -> BackgroundSession {
        let logDir = SessionStore.defaultDirectory().appendingPathComponent("logs")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        let sessionId = UUID()
        let logPath = logDir.appendingPathComponent("\(sessionId.uuidString).log")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executablePath)
        proc.arguments = args

        // Redirect stdout/stderr to log file
        FileManager.default.createFile(atPath: logPath.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logPath)
        proc.standardOutput = logHandle
        proc.standardError = logHandle

        try proc.run()

        let session = BackgroundSession(
            id: sessionId,
            pid: proc.processIdentifier,
            command: ([executablePath] + args).joined(separator: " "),
            logPath: logPath
        )

        try await store.add(session)

        // Monitor for exit in background
        let storeRef = store
        Task.detached {
            proc.waitUntilExit()
            logHandle.closeFile()
            var updated = session
            updated = BackgroundSession(
                id: session.id,
                pid: session.pid,
                startedAt: session.startedAt,
                command: session.command,
                logPath: session.logPath,
                exitCode: proc.terminationStatus,
                exitedAt: Date()
            )
            try? await storeRef.update(updated)
        }

        return session
    }

    /// Kill a background session by ID.
    public func kill(id: UUID) async throws {
        guard let session = try await store.get(id: id) else {
            throw BackgroundSessionError.sessionNotFound(id)
        }
        guard session.isRunning else {
            throw BackgroundSessionError.processNotRunning(id)
        }
        let result = Foundation.kill(session.pid, SIGTERM)
        guard result == 0 else {
            throw BackgroundSessionError.killFailed(result)
        }
    }

    /// Read the log tail for a session.
    public func logs(id: UUID, lines: Int = 50) async throws -> String {
        guard let session = try await store.get(id: id) else {
            throw BackgroundSessionError.sessionNotFound(id)
        }
        guard let data = FileManager.default.contents(atPath: session.logPath.path),
              let text = String(data: data, encoding: .utf8) else {
            throw BackgroundSessionError.logNotAvailable(session.logPath)
        }
        let allLines = text.components(separatedBy: "\n")
        let tail = Array(allLines.suffix(lines))
        return tail.joined(separator: "\n")
    }

    /// List all sessions (running and exited).
    public func list() async throws -> [BackgroundSession] {
        try await store.list()
    }

    /// Remove a session record (does not kill the process).
    public func remove(id: UUID) async throws {
        try await store.remove(id: id)
    }

    /// Clean up records for sessions that have exited.
    public func pruneExited() async throws {
        let sessions = try await store.list()
        for session in sessions where !session.isRunning && session.exitCode != nil {
            try await store.remove(id: session.id)
        }
    }
}
