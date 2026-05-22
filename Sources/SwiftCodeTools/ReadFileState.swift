/// Shared read-file state tracker.
///
/// FileEditTool requires that a file was previously read via FileReadTool before
/// it can be edited. This actor tracks that constraint.
///
/// Reference: .reference/src/tools/FileEditTool/FileEditTool.ts (readFileTimestamps)

import Foundation

// MARK: - ReadFileState

/// Actor that tracks which files have been read in the current session.
/// Keyed by absolute, normalised path.
public actor ReadFileState {

    /// Shared singleton for the process lifetime.
    public static let shared = ReadFileState()

    private var readPaths: Set<String> = []

    private init() {}

    /// Mark a file path as having been read.
    public func markRead(path: String) {
        readPaths.insert(normalize(path))
    }

    /// Returns true if the given path has been read.
    public func hasBeenRead(path: String) -> Bool {
        readPaths.contains(normalize(path))
    }

    /// Clears all state (useful in tests).
    public func reset() {
        readPaths.removeAll()
    }

    private func normalize(_ path: String) -> String {
        // Resolve symlinks / double slashes for stable keys.
        return (path as NSString).standardizingPath
    }
}
