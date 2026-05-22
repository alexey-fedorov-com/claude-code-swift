/// Shell rule matching utilities.
///
/// Mirrors the TypeScript reference at:
/// src/utils/permissions/shellRuleMatching.ts
///
/// Supports three rule types:
/// - **exact**: the command must equal the rule content exactly
/// - **prefix**: legacy `:*` syntax (e.g. `git:*` → matches any `git …` command)
/// - **wildcard**: `*` glob (e.g. `git *` → matches `git push`, `git status`, etc.)

import Foundation

// MARK: - Shell Permission Rule

/// A parsed shell permission rule.
public enum ShellPermissionRule: Sendable {
    /// Rule content must match the command exactly.
    case exact(command: String)
    /// Legacy `:*` prefix syntax — matches anything starting with the prefix.
    case prefix(prefix: String)
    /// Glob wildcard pattern using `*` as a wildcard character.
    case wildcard(pattern: String)
}

// MARK: - Prefix Extraction (legacy :* syntax)

/// Extracts the prefix from legacy `:*` syntax.
/// e.g. `"git:*"` → `"git"`, `"git push"` → `nil`.
public func permissionRuleExtractPrefix(_ rule: String) -> String? {
    guard rule.hasSuffix(":*") else { return nil }
    let prefix = String(rule.dropLast(2))
    return prefix.isEmpty ? nil : prefix
}

// MARK: - Wildcard Detection

/// Returns `true` if the pattern contains unescaped `*` characters
/// (excluding the legacy `:*` trailing suffix).
public func hasWildcards(_ pattern: String) -> Bool {
    if pattern.hasSuffix(":*") { return false }

    var i = pattern.startIndex
    while i < pattern.endIndex {
        if pattern[i] == "*" {
            // Count preceding backslashes
            var count = 0
            var j = i
            while j > pattern.startIndex {
                j = pattern.index(before: j)
                if pattern[j] == "\\" { count += 1 } else { break }
            }
            if count % 2 == 0 { return true }
        }
        i = pattern.index(after: i)
    }
    return false
}

// MARK: - Wildcard Matching

/// Matches a command string against a wildcard pattern.
///
/// - `*` matches any sequence of characters (including empty).
/// - `\*` matches a literal `*`.
/// - `\\` matches a literal `\`.
/// - A trailing ` *` (space + single unescaped wildcard) is treated as optional
///   space-plus-args, matching both `git` and `git add` for pattern `git *`.
/// - `caseInsensitive`: used for PowerShell cmdlets.
public func matchWildcardPattern(_ pattern: String, command: String, caseInsensitive: Bool = false) -> Bool {
    let trimmed = pattern.trimmingCharacters(in: .whitespaces)

    // Build a regex from the wildcard pattern
    // Step 1: parse escape sequences and collect segments
    var regexParts: [String] = []
    var unescapedStarCount = 0

    var i = trimmed.startIndex
    while i < trimmed.endIndex {
        let ch = trimmed[i]
        if ch == "\\" && trimmed.index(after: i) < trimmed.endIndex {
            let next = trimmed[trimmed.index(after: i)]
            if next == "*" {
                regexParts.append(NSRegularExpression.escapedPattern(for: "*"))
                i = trimmed.index(i, offsetBy: 2)
                continue
            } else if next == "\\" {
                regexParts.append(NSRegularExpression.escapedPattern(for: "\\"))
                i = trimmed.index(i, offsetBy: 2)
                continue
            }
        }
        if ch == "*" {
            unescapedStarCount += 1
            regexParts.append(".*")
        } else {
            regexParts.append(NSRegularExpression.escapedPattern(for: String(ch)))
        }
        i = trimmed.index(after: i)
    }

    var regexString = regexParts.joined()

    // When trailing ` *` with a single wildcard, make it optional (match bare prefix too)
    if regexString.hasSuffix(" .*") && unescapedStarCount == 1 {
        regexString = String(regexString.dropLast(3)) + "( .*)?"
    }

    let fullPattern = "^" + regexString + "$"
    var options: NSRegularExpression.Options = [.dotMatchesLineSeparators]
    if caseInsensitive { options.insert(.caseInsensitive) }

    guard let regex = try? NSRegularExpression(pattern: fullPattern, options: options) else {
        return false
    }
    let range = NSRange(command.startIndex..., in: command)
    return regex.firstMatch(in: command, options: [], range: range) != nil
}

// MARK: - Rule Parsing

/// Parses a rule content string into a typed `ShellPermissionRule`.
public func parsePermissionRule(_ ruleContent: String) -> ShellPermissionRule {
    if let prefix = permissionRuleExtractPrefix(ruleContent) {
        return .prefix(prefix: prefix)
    }
    if hasWildcards(ruleContent) {
        return .wildcard(pattern: ruleContent)
    }
    return .exact(command: ruleContent)
}

// MARK: - Matching Against a Command

/// Returns `true` if `ruleContent` matches `command`.
///
/// - In `prefix` match mode, both exact and prefix/wildcard rules fire.
/// - In `exact` match mode, only exact rules fire (wildcards are skipped for
///   security — they could match compound commands).
public func shellRuleMatches(ruleContent: String, command: String, matchMode: MatchMode = .prefix, caseInsensitive: Bool = false) -> Bool {
    let rule = parsePermissionRule(ruleContent)
    switch rule {
    case .exact(let cmd):
        return cmd == command
    case .prefix(let prefix):
        switch matchMode {
        case .exact:
            return prefix == command
        case .prefix:
            if command == prefix { return true }
            if command.hasPrefix(prefix + " ") { return true }
            // Also match "xargs <prefix>" for bare xargs
            let xargsPrefix = "xargs " + prefix
            return command == xargsPrefix || command.hasPrefix(xargsPrefix + " ")
        }
    case .wildcard(let pattern):
        // Wildcards are skipped in exact match mode for security
        if matchMode == .exact { return false }
        return matchWildcardPattern(pattern, command: command, caseInsensitive: caseInsensitive)
    }
}

/// Match mode for shell rule checking.
public enum MatchMode: Sendable {
    /// Only exact string matches.
    case exact
    /// Also allow prefix/wildcard matches (used after splitting compound commands).
    case prefix
}

// MARK: - Suggestion Helpers

/// Destination for persisting a permission update.
public enum PermissionUpdateDestination: String, Codable, Sendable {
    case userSettings
    case projectSettings
    case localSettings
    case session
    case cliArg
}

/// A permission update operation.
public enum PermissionUpdateType: String, Codable, Sendable {
    case addRules
    case removeRules
    case replaceRules
    case setMode
    case addDirectories
    case removeDirectories
}

/// Generates a permission update suggestion for an exact command match.
public func suggestionForExactCommand(toolName: String, command: String) -> [PermissionRuleValue] {
    [PermissionRuleValue(toolName: toolName, ruleContent: command)]
}

/// Generates a permission update suggestion for a prefix match.
public func suggestionForPrefix(toolName: String, prefix: String) -> [PermissionRuleValue] {
    [PermissionRuleValue(toolName: toolName, ruleContent: "\(prefix):*")]
}
