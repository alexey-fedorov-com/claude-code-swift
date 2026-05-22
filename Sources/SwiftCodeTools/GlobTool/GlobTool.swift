/// GlobTool — find files matching a glob pattern, sorted by modification time.
///
/// Reference: .reference/src/tools/GlobTool/GlobTool.ts
///
/// Uses Foundation's FileManager recursive enumeration + NSRegularExpression
/// (converted from glob via globToRegex helper). Falls back to the current
/// working directory when no explicit path is given.

import Foundation
import SwiftCodeCore

// MARK: - GlobTool

public struct GlobTool: ToolHandler {
    public let name = "Glob"
    public let description = """
        Fast file pattern matching tool that works with any codebase size. \
        Returns files matching the glob pattern, sorted by modification time \
        (newest first).
        """

    public let inputSchema = ToolInputSchema(
        properties: [
            "pattern": PropertySchema(
                type: "string",
                description: "The glob pattern to match files against (e.g. **/*.swift)."
            ),
            "path": PropertySchema(
                type: "string",
                description: "The directory to search in. Defaults to the current working directory."
            )
        ],
        required: ["pattern"]
    )

    public init() {}

    public func execute(input: [String: JSONValue]) async throws -> String {
        guard let pattern = input["pattern"]?.stringValue else {
            throw ToolError.invalidInput(tool: name, message: "pattern is required")
        }

        let searchRoot: String
        if let p = input["path"]?.stringValue, !p.isEmpty {
            searchRoot = p
        } else {
            searchRoot = FileManager.default.currentDirectoryPath
        }

        // Resolve symlinks so that /tmp → /private/tmp doesn't break prefix matching
        let rootURL = URL(fileURLWithPath: searchRoot).resolvingSymlinksInPath()

        // Convert glob to regex
        let regex: NSRegularExpression
        do {
            regex = try globToRegex(pattern)
        } catch {
            throw ToolError.invalidInput(tool: name, message: "invalid pattern: \(error.localizedDescription)")
        }

        // Walk the directory tree collecting matches + mtimes
        let matches = try await Task.detached(priority: .userInitiated) {
            try self.walkAndMatch(root: rootURL, regex: regex)
        }.value

        if matches.isEmpty {
            return "No files found"
        }

        // Sort by mtime descending (newest first)
        let sorted = matches
            .sorted { $0.mtime > $1.mtime }
            .map { $0.relativePath }

        return sorted.joined(separator: "\n")
    }

    // MARK: - Private

    private struct MatchEntry {
        let relativePath: String
        let mtime: Date
    }

    private func walkAndMatch(root: URL, regex: NSRegularExpression) throws -> [MatchEntry] {
        let fm = FileManager.default
        // Resolve the canonical root path (handles /tmp → /private/tmp on macOS)
        let canonicalRoot = (root.path as NSString).standardizingPath
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var entries: [MatchEntry] = []
        for case let url as URL in enumerator {
            // Only files
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isFile else { continue }

            // Use standardized path for prefix matching to handle symlink differences
            let canonicalPath = (url.path as NSString).standardizingPath
            let relative: String
            if canonicalPath.hasPrefix(canonicalRoot + "/") {
                relative = String(canonicalPath.dropFirst(canonicalRoot.count + 1))
            } else if canonicalPath.hasPrefix(canonicalRoot) {
                relative = String(canonicalPath.dropFirst(canonicalRoot.count))
            } else {
                relative = canonicalPath
            }

            let range = NSRange(relative.startIndex..., in: relative)
            guard regex.firstMatch(in: relative, options: [], range: range) != nil else { continue }

            let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            entries.append(MatchEntry(relativePath: relative, mtime: mtime))
        }
        return entries
    }
}

// MARK: - Glob → Regex

/// Converts a shell glob pattern to a NSRegularExpression.
/// Supports `*`, `**`, `?`, and character classes `[...]`.
private func globToRegex(_ glob: String) throws -> NSRegularExpression {
    var pattern = "^"
    var i = glob.startIndex

    while i < glob.endIndex {
        let c = glob[i]

        if c == "*" {
            let next = glob.index(after: i)
            if next < glob.endIndex && glob[next] == "*" {
                // ** — match any path including slashes
                pattern += ".*"
                i = glob.index(after: next)
                // Skip trailing slash after **
                if i < glob.endIndex && glob[i] == "/" {
                    i = glob.index(after: i)
                }
            } else {
                // * — match anything except slash
                pattern += "[^/]*"
                i = next
            }
        } else if c == "?" {
            pattern += "[^/]"
            i = glob.index(after: i)
        } else if c == "[" {
            // Pass character classes through as-is
            var j = glob.index(after: i)
            pattern += "["
            while j < glob.endIndex && glob[j] != "]" {
                pattern += NSRegularExpression.escapedPattern(for: String(glob[j]))
                j = glob.index(after: j)
            }
            pattern += "]"
            i = j < glob.endIndex ? glob.index(after: j) : j
        } else {
            pattern += NSRegularExpression.escapedPattern(for: String(c))
            i = glob.index(after: i)
        }
    }

    pattern += "$"
    return try NSRegularExpression(pattern: pattern, options: [])
}
