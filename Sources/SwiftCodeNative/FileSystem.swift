/// Filesystem helper layer.
///
/// Mirrors the TypeScript reference at:
/// - src/utils/fsOperations.ts (FsOperations / NodeFsOperations)
///
/// This is a thin, ergonomic wrapper over `Foundation.FileManager` and
/// Swift's concurrency model. For CLI use, synchronous Foundation calls
/// are fine — avoid SwiftNIO file I/O complexity.
///
/// `FileManager` is not `Sendable`, so every async method spawns a detached
/// task and uses `FileManager.default` (main-thread-safe singleton) inside it.

import Foundation

// MARK: - FileSystem

/// Provides common filesystem operations.
///
/// Operations that hit the disk are performed on a background thread via
/// `Task.detached { ... }` to keep the calling actor unblocked.
public struct FileSystem: Sendable {

    public init() {}

    // MARK: Read

    /// Reads a UTF-8 text file and returns its contents as a `String`.
    public func readUTF8(at url: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            try String(contentsOf: url, encoding: .utf8)
        }.value
    }

    // MARK: Write

    /// Writes a UTF-8 string to a file, optionally creating parent directories.
    ///
    /// - Parameters:
    ///   - contents: The text to write.
    ///   - url: Destination file URL.
    ///   - createParents: When `true`, intermediate directories are created
    ///     with `withIntermediateDirectories: true` before writing.
    public func writeUTF8(
        _ contents: String,
        to url: URL,
        createParents: Bool = false
    ) async throws {
        try await Task.detached(priority: .utility) {
            if createParents {
                let dir = url.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: dir.path) {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                }
            }
            guard let data = contents.data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            try data.write(to: url, options: .atomic)
        }.value
    }

    // MARK: Existence / type checks (synchronous — these are cheap stat calls)

    /// Returns `true` if a file or directory exists at `url`.
    public func exists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Returns `true` if `url` points to a directory.
    public func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    // MARK: Delete

    /// Removes the file or directory at `url`.
    public func delete(at url: URL) async throws {
        let path = url.path
        try await Task.detached(priority: .utility) {
            try FileManager.default.removeItem(atPath: path)
        }.value
    }

    // MARK: Create directory

    /// Creates a directory, optionally creating intermediate directories.
    public func createDirectory(
        at url: URL,
        intermediate: Bool = true
    ) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: intermediate
            )
        }.value
    }

    // MARK: Directory listing

    /// Returns the direct children of a directory.
    public func listing(at url: URL) async throws -> [URL] {
        try await Task.detached(priority: .utility) {
            try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []
            )
        }.value
    }

    // MARK: Move / copy

    /// Moves an item from `source` to `destination`.
    public func move(from source: URL, to destination: URL) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.moveItem(at: source, to: destination)
        }.value
    }

    /// Copies an item from `source` to `destination`.
    public func copy(from source: URL, to destination: URL) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.copyItem(at: source, to: destination)
        }.value
    }

    // MARK: Temporary directory

    /// Returns a URL for a new temporary directory with the given prefix.
    public func makeTemporaryDirectory(prefix: String = "swiftcode") throws -> URL {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix).\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }
}

// MARK: - Convenience static members

public extension FileSystem {
    /// Shared instance.
    static let shared = FileSystem()
}
