/// DiagnosticLogger — file-based diagnostic / debug log.
///
/// Writes structured log lines to `~/.claude/diag.log`.
/// Used for debugging without relying on telemetry opt-in.
///
/// Mirrors `src/utils/log.ts` (diagnosticLog).

import Foundation

// MARK: - LogLevel

public enum LogLevel: String, Codable, Comparable, Sendable {
    case debug, info, warn, error

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        order(lhs) < order(rhs)
    }

    private static func order(_ l: LogLevel) -> Int {
        switch l { case .debug: return 0; case .info: return 1; case .warn: return 2; case .error: return 3 }
    }
}

// MARK: - DiagnosticLogger

public actor DiagnosticLogger {
    // MARK: - Config

    private let logPath: URL
    private let minimumLevel: LogLevel
    private let maxFileSizeBytes: Int
    private let dateFormatter: ISO8601DateFormatter

    // MARK: - State

    private var fileHandle: FileHandle?

    // MARK: - Init

    public init(
        logPath: URL? = nil,
        minimumLevel: LogLevel = .info,
        maxFileSizeBytes: Int = 10 * 1024 * 1024   // 10 MB
    ) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let defaultPath = home
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("diag.log")
        self.logPath = logPath ?? defaultPath
        self.minimumLevel = minimumLevel
        self.maxFileSizeBytes = maxFileSizeBytes
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    // MARK: - Logging

    public func log(
        _ message: String,
        level: LogLevel = .info,
        metadata: [String: String] = [:],
        file: String = #file,
        line: Int = #line
    ) async {
        guard level >= minimumLevel else { return }
        let line_str = formatLine(message: message, level: level, metadata: metadata)
        await write(line_str)
    }

    public func debug(_ message: String, metadata: [String: String] = [:]) async {
        await log(message, level: .debug, metadata: metadata)
    }

    public func info(_ message: String, metadata: [String: String] = [:]) async {
        await log(message, level: .info, metadata: metadata)
    }

    public func warn(_ message: String, metadata: [String: String] = [:]) async {
        await log(message, level: .warn, metadata: metadata)
    }

    public func error(_ message: String, metadata: [String: String] = [:]) async {
        await log(message, level: .error, metadata: metadata)
    }

    // MARK: - Telemetry bridge

    /// Write a TelemetryEvent to the diagnostic log.
    public func logEvent(_ event: TelemetryEvent) async {
        let props = event.properties.map { "\($0.key)=\($0.value.value)" }.joined(separator: " ")
        await log(
            "event:\(event.name) \(props)",
            level: .debug,
            metadata: ["session": event.sessionID ?? ""]
        )
    }

    // MARK: - Private

    private func formatLine(
        message: String, level: LogLevel, metadata: [String: String]
    ) -> String {
        let ts = dateFormatter.string(from: Date())
        let metaStr = metadata.isEmpty
            ? ""
            : " " + metadata.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        return "[\(ts)] [\(level.rawValue.uppercased())] \(message)\(metaStr)\n"
    }

    private func write(_ line: String) async {
        let fm = FileManager.default
        let dir = logPath.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Rotate if too large
        if let attrs = try? fm.attributesOfItem(atPath: logPath.path),
           let size = attrs[.size] as? Int, size > maxFileSizeBytes {
            rotate()
        }

        // Append
        guard let data = line.data(using: .utf8) else { return }
        if fm.fileExists(atPath: logPath.path) {
            if fileHandle == nil {
                fileHandle = try? FileHandle(forWritingTo: logPath)
                fileHandle?.seekToEndOfFile()
            }
            fileHandle?.write(data)
        } else {
            fm.createFile(atPath: logPath.path, contents: data)
            fileHandle = try? FileHandle(forWritingTo: logPath)
            fileHandle?.seekToEndOfFile()
        }
    }

    private func rotate() {
        try? fileHandle?.close()
        fileHandle = nil
        let rotated = logPath.deletingPathExtension()
            .appendingPathExtension("old.log")
        try? FileManager.default.moveItem(at: logPath, to: rotated)
    }

    // MARK: - Flush

    public func flush() async {
        try? fileHandle?.synchronize()
    }
}

// MARK: - Shared instance

extension DiagnosticLogger {
    public static let shared = DiagnosticLogger()
}
