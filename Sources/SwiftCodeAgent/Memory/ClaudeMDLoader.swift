/// ClaudeMDLoader — discover and load CLAUDE.md files.
///
/// Discovery order (mirrors `src/utils/claudemd.ts`):
///   1. Walk from CWD upward through parent directories, collecting CLAUDE.md files.
///   2. Check `.claude/CLAUDE.md` inside each directory on the way up.
///   3. Check `~/CLAUDE.md` (user home).
///   4. Recursively resolve `@path` includes within each file.
///
/// All files are returned in outermost-first order (root → CWD), so later
/// entries take precedence when concatenated into the system prompt.

import Foundation

// MARK: - LoadedMemory

public struct LoadedMemory: Sendable {
    /// Absolute path to the CLAUDE.md file.
    public let path: URL
    /// Parsed frontmatter key-value pairs.
    public let frontmatter: [String: String]
    /// Parsed frontmatter list values (e.g. `paths:` globs).
    public let frontmatterLists: [String: [String]]
    /// Body content (HTML comments stripped, `@path` lines removed).
    public let body: String
    /// Recursively loaded `@path` includes, in order.
    public let included: [LoadedMemory]
}

// MARK: - FileSystem abstraction (for testing)

public struct FileSystem: Sendable {
    public var fileExists: @Sendable (URL) -> Bool
    public var readString: @Sendable (URL) throws -> String
    public var contentsOfDirectory: @Sendable (URL) throws -> [URL]

    public init(
        fileExists: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        readString: @escaping @Sendable (URL) throws -> String = { try String(contentsOf: $0, encoding: .utf8) },
        contentsOfDirectory: @escaping @Sendable (URL) throws -> [URL] = {
            try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)
        }
    ) {
        self.fileExists = fileExists
        self.readString = readString
        self.contentsOfDirectory = contentsOfDirectory
    }
}

// MARK: - ClaudeMDLoader

public actor ClaudeMDLoader {
    private let fs: FileSystem
    /// Tracks visited paths to prevent include cycles.
    private var visited: Set<String> = []

    public init(fileSystem: FileSystem = FileSystem()) {
        self.fs = fileSystem
    }

    /// Discover all relevant CLAUDE.md files for the given working directory.
    ///
    /// - Parameters:
    ///   - workingDirectory: The project CWD (e.g. current git repo root or process CWD).
    ///   - userDirectory: The user home directory.
    /// - Returns: Loaded memories in outermost-first order.
    public func discover(
        workingDirectory: URL,
        userDirectory: URL
    ) async throws -> [LoadedMemory] {
        visited.removeAll()
        var results: [LoadedMemory] = []

        // Collect candidate directories from CWD → filesystem root
        let chain = directoryChain(from: workingDirectory)

        // Load in reverse (outermost first) so later = closer to CWD
        for dir in chain.reversed() {
            // CLAUDE.md directly in the directory
            let direct = dir.appendingPathComponent("CLAUDE.md")
            if let m = try await load(path: direct) { results.append(m) }

            // .claude/CLAUDE.md subdirectory variant
            let dotclaude = dir
                .appendingPathComponent(".claude", isDirectory: true)
                .appendingPathComponent("CLAUDE.md")
            if let m = try await load(path: dotclaude) { results.append(m) }
        }

        // User-level: ~/CLAUDE.md
        let userMD = userDirectory.appendingPathComponent("CLAUDE.md")
        if let m = try await load(path: userMD) { results.append(m) }

        return results
    }

    // MARK: - Private

    /// Load a single CLAUDE.md file and resolve its `@path` includes.
    private func load(path: URL) async throws -> LoadedMemory? {
        let canonical = path.standardized.path
        guard fs.fileExists(path), !visited.contains(canonical) else { return nil }
        visited.insert(canonical)

        let source = try fs.readString(path)
        let parsed = ClaudeMDParser.parse(source)

        var included: [LoadedMemory] = []
        for includePath in parsed.includes {
            let resolvedURL = resolve(includePath, relativeTo: path.deletingLastPathComponent())
            if let child = try await load(path: resolvedURL) {
                included.append(child)
            }
        }

        return LoadedMemory(
            path: path,
            frontmatter: parsed.frontmatter,
            frontmatterLists: parsed.frontmatterLists,
            body: parsed.body,
            included: included
        )
    }

    /// Walk from `dir` up to the filesystem root, returning each directory.
    private func directoryChain(from dir: URL) -> [URL] {
        var chain: [URL] = []
        var current = dir.standardized
        while true {
            chain.append(current)
            let parent = current.deletingLastPathComponent().standardized
            if parent.path == current.path { break } // at root
            current = parent
        }
        return chain // CWD-first order; caller reverses as needed
    }

    /// Resolve an include path: if absolute use as-is; otherwise relative to `base`.
    private func resolve(_ includePath: String, relativeTo base: URL) -> URL {
        if includePath.hasPrefix("/") {
            return URL(fileURLWithPath: includePath)
        }
        return base.appendingPathComponent(includePath)
    }
}

// MARK: - Concatenation helper

extension [LoadedMemory] {
    /// Concatenate all bodies (recursively including `included`) in order.
    public func concatenatedContent() -> String {
        flatMap { flatten($0) }
            .map(\.body)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func flatten(_ m: LoadedMemory) -> [LoadedMemory] {
        [m] + m.included.flatMap { flatten($0) }
    }
}
