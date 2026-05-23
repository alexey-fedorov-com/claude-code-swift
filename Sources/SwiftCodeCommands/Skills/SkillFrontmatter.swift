/// SkillFrontmatter — simple YAML frontmatter parser for SKILL.md files.
///
/// Mirrors .reference/src/utils/frontmatterParser.ts.
///
/// Parses the `---\nkey: value\n---\n` block at the top of Markdown files.
/// This is a line-based parser — no nested YAML support needed for SKILL.md.

import Foundation

// MARK: - SkillFrontmatter

public enum SkillFrontmatter {
    // MARK: - Errors

    public enum ParseError: Error, LocalizedError {
        case malformedFrontmatter(String)

        public var errorDescription: String? {
            switch self {
            case .malformedFrontmatter(let detail):
                return "Malformed skill frontmatter: \(detail)"
            }
        }
    }

    // MARK: - Parse

    /// Parses YAML frontmatter from a Markdown string.
    ///
    /// Expected format:
    /// ```
    /// ---
    /// key: value
    /// another: "quoted value"
    /// list:
    ///   - item1
    ///   - item2
    /// ---
    /// Body text here.
    /// ```
    ///
    /// - Parameter markdown: Full Markdown file contents.
    /// - Returns: `(frontmatter, body)` where frontmatter is a flat `[String: String]` map
    ///   and body is the content after the closing `---`.
    public static func parse(_ markdown: String) throws -> (frontmatter: [String: String], body: String) {
        let lines = markdown.components(separatedBy: "\n")

        // Must start with `---`
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return ([:], markdown)
        }

        // Find closing `---`
        var closingIndex: Int? = nil
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                closingIndex = i
                break
            }
        }

        guard let closingIdx = closingIndex else {
            // No closing --- found: treat entire file as body
            return ([:], markdown)
        }

        let frontmatterLines = Array(lines[1..<closingIdx])
        let bodyLines = closingIdx + 1 < lines.count ? Array(lines[(closingIdx + 1)...]) : []
        let body = bodyLines.joined(separator: "\n")

        // Parse frontmatter as flat key: value pairs
        var result: [String: String] = [:]
        var currentKey: String? = nil
        var listValues: [String] = []

        func flushList() {
            if let key = currentKey, !listValues.isEmpty {
                result[key] = listValues.joined(separator: ",")
                listValues = []
                currentKey = nil
            }
        }

        for line in frontmatterLines {
            // List item continuation
            if line.hasPrefix("  - ") || line.hasPrefix("- ") {
                let value = line
                    .trimmingCharacters(in: .whitespaces)
                    .dropFirst(2) // remove "- "
                listValues.append(String(value).trimmingCharacters(in: .init(charactersIn: "\"'")))
                continue
            }

            // New key: value line
            if let colonRange = line.range(of: ":") {
                flushList()
                let key = String(line[line.startIndex..<colonRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let rawValue = String(line[colonRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)

                if rawValue.isEmpty {
                    // This is a list key — accumulate items on next lines
                    currentKey = key
                } else {
                    // Strip optional quotes
                    let value = rawValue.trimmingCharacters(in: .init(charactersIn: "\"'"))
                    result[key] = value
                }
            }
        }

        flushList()

        return (result, body)
    }

    // MARK: - Helpers

    /// Extracts a string value for a known key from frontmatter.
    public static func string(_ key: String, from frontmatter: [String: String]) -> String? {
        frontmatter[key]
    }

    /// Extracts a comma-separated list value from frontmatter.
    public static func list(_ key: String, from frontmatter: [String: String]) -> [String] {
        guard let raw = frontmatter[key], !raw.isEmpty else { return [] }
        return raw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Extracts a boolean value from frontmatter.
    public static func bool(_ key: String, from frontmatter: [String: String]) -> Bool? {
        guard let raw = frontmatter[key] else { return nil }
        switch raw.lowercased() {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }
}
