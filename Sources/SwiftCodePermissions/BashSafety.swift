/// Bash tool safety classifiers.
///
/// Mirrors the TypeScript reference at:
/// - src/tools/BashTool/readOnlyValidation.ts   (read-only command list)
/// - src/tools/BashTool/destructiveCommandWarning.ts (destructive patterns)
/// - src/utils/permissions/filesystem.ts         (dangerous dirs/files)
///
/// Backported from 2.1.90:
/// - `.husky` added to `dangerousDirectories`
/// - `Get-DnsClientCache` and `ipconfig /displaydns` NOT in read-only lists
///   (those are PowerShell; kept here as documentation that we consciously
///   excluded them from the Bash allowlist too).

import Foundation

// MARK: - Dangerous Filesystem Locations

/// Directories that should be protected from auto-editing.
/// Includes `.husky` (backported from 2.1.90).
public let dangerousDirectories: Set<String> = [
    ".git",
    ".vscode",
    ".idea",
    ".claude",
    ".husky",   // backported from 2.1.90
]

/// Files that should be protected from auto-editing.
public let dangerousFiles: Set<String> = [
    ".gitconfig",
    ".gitmodules",
    ".bashrc",
    ".bash_profile",
    ".zshrc",
    ".zprofile",
    ".profile",
    ".ripgreprc",
    ".mcp.json",
    ".claude.json",
]

/// Returns `true` if any path segment matches a dangerous directory or file (case-insensitive).
public func pathIsDangerous(_ path: String) -> Bool {
    // Split by both separators to handle cross-platform paths
    let separatorChars = CharacterSet(charactersIn: "/\\")
    let segments = path.components(separatedBy: separatorChars).filter { !$0.isEmpty }

    for segment in segments {
        let lc = segment.lowercased()
        // Check dangerous directories
        for dir in dangerousDirectories {
            if lc == dir.lowercased() { return true }
        }
        // Check dangerous files (leaf nodes)
        for file in dangerousFiles {
            if lc == file.lowercased() { return true }
        }
    }
    return false
}

// MARK: - Read-Only Commands

/// Simple commands (no dangerous flags) that are safe to auto-approve.
/// Derived from `READONLY_COMMANDS` in readOnlyValidation.ts.
///
/// Note: This is a representative canonical macOS/bash subset.
/// Windows-specific commands (e.g. Get-*, ipconfig) are in PowerShellSafety.
public let bashReadOnlyCommands: Set<String> = [
    // File content viewing
    "cat", "head", "tail", "wc", "stat", "strings", "hexdump", "od", "nl",

    // Text processing
    "cut", "paste", "tr", "column", "tac", "rev", "fold", "expand",
    "unexpand", "fmt", "comm", "cmp", "numfmt",

    // Path / filesystem info
    "ls", "pwd", "basename", "dirname", "realpath", "readlink", "find",

    // Search
    "grep", "rg", "awk",

    // Diff / compare
    "diff",

    // System info
    "id", "uname", "free", "df", "du", "locale", "groups", "nproc",

    // Time / date (display only, not set)
    "cal", "uptime", "date",

    // Process info
    "ps", "pgrep", "lsof",

    // Network info (read-only display)
    "netstat", "ss", "hostname",

    // Checksum
    "sha256sum", "sha1sum", "md5sum",

    // Misc safe
    "sleep", "which", "type", "expr", "test",
    "true", "false", "echo", "printf",

    // Paging / help
    "man", "info", "help",

    // Git (read-only subcommands handled separately via prefix rules)
    "git diff", "git log", "git status", "git show",
    "git branch", "git tag", "git remote", "git ls-files",
    "git ls-remote", "git stash list", "git stash show",
    "git rev-parse", "git rev-list", "git describe",
    "git shortlog", "git blame", "git reflog",
    "git config --list", "git config --get",
]

/// Returns `true` if the given command is in the read-only allow list.
/// Matching is prefix-based: `"ls -la"` matches because `"ls"` is in the list.
public func bashCommandIsReadOnly(_ command: String) -> Bool {
    let trimmed = command.trimmingCharacters(in: .whitespaces)
    for readOnly in bashReadOnlyCommands {
        if trimmed == readOnly { return true }
        if trimmed.hasPrefix(readOnly + " ") { return true }
    }
    return false
}

// MARK: - Destructive Command Patterns

private struct DestructivePattern {
    let pattern: NSRegularExpression
    let warning: String
}

private let destructivePatterns: [DestructivePattern] = [
    // Git — data loss
    makePattern(#"\bgit\s+reset\s+--hard\b"#,
                warning: "Note: may discard uncommitted changes"),
    makePattern(#"\bgit\s+push\b[^;&|\n]*[ \t](--force|--force-with-lease|-f)\b"#,
                warning: "Note: may overwrite remote history"),
    makePattern(#"\bgit\s+clean\b(?![^;&|\n]*(?:-[a-zA-Z]*n|--dry-run))[^;&|\n]*-[a-zA-Z]*f"#,
                warning: "Note: may permanently delete untracked files"),
    makePattern(#"\bgit\s+checkout\s+(--\s+)?\.[ \t]*($|[;&|\n])"#,
                warning: "Note: may discard all working tree changes"),
    makePattern(#"\bgit\s+restore\s+(--\s+)?\.[ \t]*($|[;&|\n])"#,
                warning: "Note: may discard all working tree changes"),
    makePattern(#"\bgit\s+stash[ \t]+(drop|clear)\b"#,
                warning: "Note: may permanently remove stashed changes"),
    makePattern(#"\bgit\s+branch\s+(-D[ \t]|--delete\s+--force|--force\s+--delete)\b"#,
                warning: "Note: may force-delete a branch"),

    // Git — safety bypass
    makePattern(#"\bgit\s+(commit|push|merge)\b[^;&|\n]*--no-verify\b"#,
                warning: "Note: may skip safety hooks"),
    makePattern(#"\bgit\s+commit\b[^;&|\n]*--amend\b"#,
                warning: "Note: may rewrite the last commit"),

    // File deletion
    makePattern(#"(^|[;&|\n]\s*)rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f|(^|[;&|\n]\s*)rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR]"#,
                warning: "Note: may recursively force-remove files"),
    makePattern(#"(^|[;&|\n]\s*)rm\s+-[a-zA-Z]*[rR]"#,
                warning: "Note: may recursively remove files"),
    makePattern(#"(^|[;&|\n]\s*)rm\s+-[a-zA-Z]*f"#,
                warning: "Note: may force-remove files"),

    // Database
    makePattern(#"\b(DROP|TRUNCATE)\s+(TABLE|DATABASE|SCHEMA)\b"#,
                warning: "Note: may drop or truncate database objects",
                options: [.caseInsensitive]),
    makePattern(#"\bDELETE\s+FROM\s+\w+[ \t]*(;|"|'|\n|$)"#,
                warning: "Note: may delete all rows from a database table",
                options: [.caseInsensitive]),

    // Infrastructure
    makePattern(#"\bkubectl\s+delete\b"#,
                warning: "Note: may delete Kubernetes resources"),
    makePattern(#"\bterraform\s+destroy\b"#,
                warning: "Note: may destroy Terraform infrastructure"),
]

private func makePattern(_ pattern: String, warning: String, options: NSRegularExpression.Options = []) -> DestructivePattern {
    // swiftlint:disable:next force_try
    let regex = try! NSRegularExpression(pattern: pattern, options: options)
    return DestructivePattern(pattern: regex, warning: warning)
}

/// Checks if a bash command matches any known destructive pattern.
/// Returns a human-readable warning string, or `nil` if none detected.
public func getDestructiveCommandWarning(_ command: String) -> String? {
    let range = NSRange(command.startIndex..., in: command)
    for dp in destructivePatterns {
        if dp.pattern.firstMatch(in: command, options: [], range: range) != nil {
            return dp.warning
        }
    }
    return nil
}

// MARK: - Bypass Mode Killswitch

/// Returns `true` if bypass permissions mode is disabled by environment or policy.
///
/// Mirrors the killswitch checks in `src/utils/permissions/bypassPermissionsKillswitch.ts`.
public func isBypassPermissionsModeKillswitched() -> Bool {
    let env = ProcessInfo.processInfo.environment
    // Env-var killswitch: CLAUDE_CODE_DISABLE_NONINTERACTIVE_BYPASS_PERMISSIONS=1
    if let val = env["CLAUDE_CODE_DISABLE_NONINTERACTIVE_BYPASS_PERMISSIONS"],
       val == "1" || val.lowercased() == "true" {
        return true
    }
    return false
}

// MARK: - YoloClassifier (stub)

/// Result of the auto-mode (yolo) classifier.
public struct YoloClassifierResult: Sendable {
    public let shouldBlock: Bool
    public let reason: String
    public let unavailable: Bool

    public init(shouldBlock: Bool, reason: String, unavailable: Bool = false) {
        self.shouldBlock = shouldBlock
        self.reason = reason
        self.unavailable = unavailable
    }
}

/// Auto-mode classifier stub.
///
/// The original implementation (`yoloClassifier.ts`, 52 KB) requires three
/// prompt `.txt` files that were dead-code-eliminated by the
/// `TRANSCRIPT_CLASSIFIER` feature flag (always `false` in this build).
///
/// This stub always returns "don't block" (the safe default for a missing
/// classifier — callers fall back to normal permission prompting).
///
/// TODO: Implement when TRANSCRIPT_CLASSIFIER is enabled and the prompt files
/// are available. Reference: .reference/src/utils/permissions/yoloClassifier.ts
public struct YoloClassifier: Sendable {
    public init() {}

    public func classify(command: String, context: String = "") -> YoloClassifierResult {
        // TRANSCRIPT_CLASSIFIER = false in this build.
        // The classifier prompt files were DCE'd and are unavailable.
        // Return safe default: don't block, but mark as unavailable.
        return YoloClassifierResult(
            shouldBlock: false,
            reason: "YoloClassifier unavailable: TRANSCRIPT_CLASSIFIER is false and prompt files are missing",
            unavailable: true
        )
    }
}
