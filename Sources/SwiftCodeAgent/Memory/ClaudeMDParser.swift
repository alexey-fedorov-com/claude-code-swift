/// ClaudeMDParser — parse CLAUDE.md content.
///
/// Handles:
///   - YAML-style frontmatter (--- delimited, key: value lines)
///   - `@path` include directives on their own line
///   - HTML comment stripping (<!-- ... -->)
///   - `paths:` glob list in frontmatter
///
/// Mirrors `src/utils/claudemd.ts`.

import Foundation

// MARK: - ParsedClaudeMD

public struct ParsedClaudeMD: Sendable {
    /// Frontmatter key-value pairs (string values only; lists go to `frontmatterLists`).
    public let frontmatter: [String: String]
    /// List-valued frontmatter keys (e.g. `paths:` → ["./**", "src/**"]).
    public let frontmatterLists: [String: [String]]
    /// Body content with HTML comments stripped and `@path` lines removed.
    public let body: String
    /// Raw `@path` include directives found in the body (unresolved paths).
    public let includes: [String]
}

// MARK: - ClaudeMDParser

public enum ClaudeMDParser {

    /// Parse raw CLAUDE.md content.
    public static func parse(_ source: String) -> ParsedClaudeMD {
        var lines = source.components(separatedBy: "\n")
        var frontmatter: [String: String] = [:]
        var frontmatterLists: [String: [String]] = [:]
        var bodyLines: [String] = []
        var includes: [String] = []

        // --- Frontmatter extraction ---
        var idx = 0
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            idx = 1
            var fmLines: [String] = []
            while idx < lines.count {
                let line = lines[idx]
                if line.trimmingCharacters(in: .whitespaces) == "---" { idx += 1; break }
                fmLines.append(line)
                idx += 1
            }
            parseFrontmatter(fmLines, into: &frontmatter, lists: &frontmatterLists)
        }

        // --- Body processing ---
        bodyLines = Array(lines[idx...])
        let joinedBody = bodyLines.joined(separator: "\n")

        // Strip HTML comments
        let stripped = stripHTMLComments(joinedBody)

        // Extract @path includes
        var cleanLines: [String] = []
        for line in stripped.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("@") {
                let path = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !path.isEmpty { includes.append(path) }
                // @path lines are consumed, not emitted in body
            } else {
                cleanLines.append(line)
            }
        }

        let body = cleanLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedClaudeMD(
            frontmatter: frontmatter,
            frontmatterLists: frontmatterLists,
            body: body,
            includes: includes
        )
    }

    // MARK: - Private helpers

    private static func parseFrontmatter(
        _ lines: [String],
        into dict: inout [String: String],
        lists: inout [String: [String]]
    ) {
        var i = 0
        while i < lines.count {
            let line = lines[i]
            // Scalar: "key: value"
            if let colonIdx = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIdx])
                    .trimmingCharacters(in: .whitespaces)
                let afterColon = String(line[line.index(after: colonIdx)...])
                    .trimmingCharacters(in: .whitespaces)

                if afterColon.isEmpty {
                    // List block: lines until next non-indented key
                    var items: [String] = []
                    i += 1
                    while i < lines.count {
                        let item = lines[i]
                        let isListItem = item.hasPrefix("  ") || item.hasPrefix("\t")
                        guard isListItem else { break }
                        let cleaned = item
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                            .trimmingCharacters(in: .whitespaces)
                        if !cleaned.isEmpty { items.append(cleaned) }
                        i += 1
                    }
                    lists[key] = items
                    continue
                } else {
                    dict[key] = afterColon
                }
            }
            i += 1
        }
    }

    private static func stripHTMLComments(_ s: String) -> String {
        var result = s
        while let openRange = result.range(of: "<!--") {
            if let closeRange = result.range(of: "-->", range: openRange.upperBound..<result.endIndex) {
                result.removeSubrange(openRange.lowerBound..<closeRange.upperBound)
            } else {
                // Unclosed comment — strip from open to end
                result.removeSubrange(openRange.lowerBound..<result.endIndex)
                break
            }
        }
        return result
    }
}
