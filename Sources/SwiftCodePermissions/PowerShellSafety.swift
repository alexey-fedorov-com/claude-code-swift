/// PowerShell tool safety classifiers.
///
/// Mirrors the TypeScript reference at:
/// - src/tools/PowerShellTool/readOnlyValidation.ts
/// - src/tools/PowerShellTool/destructiveCommandWarning.ts
///
/// Backported from 2.1.90:
/// - `Get-DnsClientCache` is NOT in the read-only list (removed for DNS cache privacy).
/// - `ipconfig /displaydns` is NOT in the read-only list (removed for DNS cache privacy).

import Foundation

// MARK: - Read-Only PowerShell Cmdlets

/// PowerShell cmdlets that are safe for auto-approval (read-only).
/// All matching should be case-insensitive (PowerShell is case-insensitive).
///
/// NOTE: DNS cache commands deliberately excluded per 2.1.90 backport:
/// - `Get-DnsClientCache` — removed for DNS cache privacy
/// - `ipconfig /displaydns` — removed for DNS cache privacy
public let powershellReadOnlyCmdlets: Set<String> = [
    // Process info
    "get-process",
    "get-job",
    "get-service",

    // Filesystem (read)
    "get-childitem", "gci", "ls", "dir",
    "get-item", "gi",
    "get-content", "gc", "cat", "type",
    "get-location", "gl", "pwd",
    "test-path",
    "resolve-path",
    "split-path",
    "join-path",
    "get-acl",

    // System info
    "get-host",
    "get-date",
    "get-culture",
    "get-uiculture",
    "get-command", "gcm",
    "get-help",
    "get-module",
    "get-psprovider",
    "get-psdrive",
    "get-variable", "gv",
    "get-alias", "gal",
    "get-executionpolicy",
    "get-history",
    "get-pssession",

    // Environment
    "get-itemproperty",  // reading registry / properties

    // Networking (read-only display — DNS cache excluded)
    "test-connection",
    "get-netadapter",
    "get-netipaddress",
    "get-netroute",
    "netstat",

    // Git (read-only)
    "git status",
    "git log",
    "git diff",
    "git show",
    "git branch",
    "git remote",

    // .NET info
    "dotnet --version",
    "dotnet --info",
    "dotnet --list-sdks",
    "dotnet --list-runtimes",

    // Misc
    "write-output",
    "write-host",
    "format-list",
    "format-table",
    "format-wide",
    "select-object",
    "where-object",
    "sort-object",
    "measure-object",
    "compare-object",
    "group-object",
    "select-string",
]

/// Returns `true` if the given PowerShell command appears to be read-only.
/// Matching is case-insensitive and prefix-based.
public func powershellCommandIsReadOnly(_ command: String) -> Bool {
    let trimmed = command.trimmingCharacters(in: .whitespaces).lowercased()
    for cmdlet in powershellReadOnlyCmdlets {
        let lc = cmdlet.lowercased()
        if trimmed == lc { return true }
        if trimmed.hasPrefix(lc + " ") { return true }
        if trimmed.hasPrefix(lc + "\t") { return true }
    }
    return false
}

// MARK: - Destructive PowerShell Patterns

private struct PSDestructivePattern {
    let pattern: NSRegularExpression
    let warning: String
}

private func psMakePattern(_ pattern: String, warning: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> PSDestructivePattern {
    // swiftlint:disable:next force_try
    let regex = try! NSRegularExpression(pattern: pattern, options: options)
    return PSDestructivePattern(pattern: regex, warning: warning)
}

private let psDestructivePatterns: [PSDestructivePattern] = [
    // File deletion
    psMakePattern(#"\bremove-item\b"#, warning: "Note: may remove files or directories"),
    psMakePattern(#"\bri\b"#, warning: "Note: may remove files or directories"),
    psMakePattern(#"\bdel\b"#, warning: "Note: may remove files"),
    psMakePattern(#"\brm\b"#, warning: "Note: may remove files"),

    // Process termination
    psMakePattern(#"\bstop-process\b"#, warning: "Note: may stop running processes"),
    psMakePattern(#"\bkill\b"#, warning: "Note: may kill processes"),

    // Service control
    psMakePattern(#"\bstop-service\b"#, warning: "Note: may stop system services"),
    psMakePattern(#"\brestart-service\b"#, warning: "Note: may restart system services"),

    // Git — data loss
    psMakePattern(#"\bgit\s+reset\s+--hard\b"#, warning: "Note: may discard uncommitted changes"),
    psMakePattern(#"\bgit\s+push\b[^;&|\n]*\s(--force|--force-with-lease|-f)\b"#,
                  warning: "Note: may overwrite remote history"),
    psMakePattern(#"\bgit\s+clean\b[^;&|\n]*-[a-zA-Z]*f"#,
                  warning: "Note: may permanently delete untracked files"),

    // Database
    psMakePattern(#"\b(DROP|TRUNCATE)\s+(TABLE|DATABASE|SCHEMA)\b"#,
                  warning: "Note: may drop or truncate database objects"),

    // Infrastructure
    psMakePattern(#"\bkubectl\s+delete\b"#, warning: "Note: may delete Kubernetes resources"),
    psMakePattern(#"\bterraform\s+destroy\b"#, warning: "Note: may destroy Terraform infrastructure"),

    // Dangerous PowerShell-specific
    psMakePattern(#"\bformat-volume\b"#, warning: "Note: may format a volume"),
    psMakePattern(#"\bclear-disk\b"#, warning: "Note: may clear all disk data"),
    psMakePattern(#"\binvoke-expression\b"#, warning: "Note: may execute arbitrary code"),
    psMakePattern(#"\biex\b"#, warning: "Note: may execute arbitrary code"),
]

/// Checks if a PowerShell command matches any known destructive pattern.
/// Returns a human-readable warning string, or `nil` if none detected.
public func getPowerShellDestructiveCommandWarning(_ command: String) -> String? {
    let range = NSRange(command.startIndex..., in: command)
    for dp in psDestructivePatterns {
        if dp.pattern.firstMatch(in: command, options: [], range: range) != nil {
            return dp.warning
        }
    }
    return nil
}
