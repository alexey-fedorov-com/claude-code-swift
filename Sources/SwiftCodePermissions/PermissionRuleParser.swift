/// Permission rule types and parser.
///
/// Mirrors the TypeScript reference at:
/// - src/types/permissions.ts (PermissionRuleValue, PermissionBehavior, PermissionRule)
/// - src/utils/permissions/permissionRuleParser.ts (parse/format logic)

import Foundation

// MARK: - Core Types

/// How a permission rule behaves when matched.
public enum PermissionBehavior: String, Codable, Sendable {
    case allow
    case deny
    case ask
}

/// Where a permission rule originated from.
public enum PermissionRuleSource: String, Codable, Sendable {
    case userSettings
    case projectSettings
    case localSettings
    case flagSettings
    case policySettings
    case cliArg
    case command
    case session
}

/// Specifies which tool and optional content a permission rule targets.
public struct PermissionRuleValue: Codable, Equatable, Sendable {
    public var toolName: String
    public var ruleContent: String?

    public init(toolName: String, ruleContent: String? = nil) {
        self.toolName = toolName
        self.ruleContent = ruleContent
    }
}

/// A permission rule with its source and behavior.
public struct PermissionRule: Codable, Sendable {
    public var source: PermissionRuleSource
    public var ruleBehavior: PermissionBehavior
    public var ruleValue: PermissionRuleValue

    public init(source: PermissionRuleSource, ruleBehavior: PermissionBehavior, ruleValue: PermissionRuleValue) {
        self.source = source
        self.ruleBehavior = ruleBehavior
        self.ruleValue = ruleValue
    }
}

// MARK: - Legacy Tool Name Aliases

/// Maps legacy tool names to current canonical names.
/// Keep in sync with the TypeScript reference.
private let legacyToolNameAliases: [String: String] = [
    "Task": "Agent",
    "KillShell": "TaskStop",
    "AgentOutputTool": "TaskOutput",
    "BashOutputTool": "TaskOutput",
]

public func normalizeLegacyToolName(_ name: String) -> String {
    legacyToolNameAliases[name] ?? name
}

// MARK: - Escape / Unescape

/// Escapes parentheses and backslashes in rule content for storage.
///
/// Escaping order:
/// 1. `\` → `\\`
/// 2. `(` → `\(`
/// 3. `)` → `\)`
public func escapeRuleContent(_ content: String) -> String {
    content
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "(", with: "\\(")
        .replacingOccurrences(of: ")", with: "\\)")
}

/// Reverses `escapeRuleContent`.
///
/// Unescaping order (reverse of escaping):
/// 1. `\(` → `(`
/// 2. `\)` → `)`
/// 3. `\\` → `\`
public func unescapeRuleContent(_ content: String) -> String {
    // Process character by character to handle escape sequences correctly
    var output = ""
    var chars = content.makeIterator()
    while let ch = chars.next() {
        if ch == "\\" {
            if let next = chars.next() {
                switch next {
                case "(": output.append("(")
                case ")": output.append(")")
                case "\\": output.append("\\")
                default:
                    output.append(ch)
                    output.append(next)
                }
            } else {
                output.append(ch)
            }
        } else {
            output.append(ch)
        }
    }
    return output
}

// MARK: - Parser

/// Counts the number of backslashes immediately before index `i` in `s`.
private func countBackslashesBefore(_ i: String.Index, in s: String) -> Int {
    guard i > s.startIndex else { return 0 }
    var count = 0
    var j = s.index(before: i)
    while s[j] == "\\" {
        count += 1
        if j == s.startIndex { break }
        j = s.index(before: j)
    }
    return count
}

/// Finds the first index of `char` that is not preceded by an odd number of backslashes.
private func findFirstUnescaped(_ char: Character, in s: String) -> String.Index? {
    var i = s.startIndex
    while i < s.endIndex {
        if s[i] == char && countBackslashesBefore(i, in: s) % 2 == 0 {
            return i
        }
        i = s.index(after: i)
    }
    return nil
}

/// Finds the last index of `char` that is not preceded by an odd number of backslashes.
private func findLastUnescaped(_ char: Character, in s: String) -> String.Index? {
    var result: String.Index? = nil
    var i = s.startIndex
    while i < s.endIndex {
        if s[i] == char && countBackslashesBefore(i, in: s) % 2 == 0 {
            result = i
        }
        i = s.index(after: i)
    }
    return result
}

/// Parses a rule string like `"Bash"` or `"Bash(git push)"` into its components.
///
/// Format: `"ToolName"` or `"ToolName(content)"`.
/// Content may contain escaped parens (`\(`, `\)`) and backslashes (`\\`).
///
/// Examples:
/// - `"Bash"` → toolName="Bash", ruleContent=nil
/// - `"Bash(npm install)"` → toolName="Bash", ruleContent="npm install"
/// - `"Bash(git *)"` → toolName="Bash", ruleContent="git *"
/// - `"Bash(python -c \"print\\(1\\)\")"` → toolName="Bash", ruleContent=`python -c "print(1)"`
public func permissionRuleValueFromString(_ ruleString: String) -> PermissionRuleValue {
    guard let openIdx = findFirstUnescaped("(", in: ruleString) else {
        return PermissionRuleValue(toolName: normalizeLegacyToolName(ruleString))
    }

    guard let closeIdx = findLastUnescaped(")", in: ruleString),
          closeIdx > openIdx else {
        return PermissionRuleValue(toolName: normalizeLegacyToolName(ruleString))
    }

    // Closing paren must be at the very end
    guard ruleString.index(after: closeIdx) == ruleString.endIndex else {
        return PermissionRuleValue(toolName: normalizeLegacyToolName(ruleString))
    }

    let toolName = String(ruleString[ruleString.startIndex..<openIdx])
    guard !toolName.isEmpty else {
        return PermissionRuleValue(toolName: normalizeLegacyToolName(ruleString))
    }

    let contentStart = ruleString.index(after: openIdx)
    let rawContent = String(ruleString[contentStart..<closeIdx])

    // Empty content or bare wildcard → tool-wide rule (no ruleContent)
    if rawContent.isEmpty || rawContent == "*" {
        return PermissionRuleValue(toolName: normalizeLegacyToolName(toolName))
    }

    let ruleContent = unescapeRuleContent(rawContent)
    return PermissionRuleValue(toolName: normalizeLegacyToolName(toolName), ruleContent: ruleContent)
}

/// Converts a `PermissionRuleValue` back to its string representation.
///
/// Examples:
/// - `{toolName:"Bash"}` → `"Bash"`
/// - `{toolName:"Bash", ruleContent:"npm install"}` → `"Bash(npm install)"`
public func permissionRuleValueToString(_ ruleValue: PermissionRuleValue) -> String {
    guard let content = ruleValue.ruleContent else {
        return ruleValue.toolName
    }
    let escaped = escapeRuleContent(content)
    return "\(ruleValue.toolName)(\(escaped))"
}
