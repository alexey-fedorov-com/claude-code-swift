/// Shell quoting/escaping utilities.
///
/// Mirrors the behavior of the `shell-quote` npm package used by the reference
/// implementation (src/utils/Shell.ts).
///
/// Bash quoting algorithm (matches `shell-quote` npm):
///   1. Safe tokens (alphanumeric + `@%+=:,./-_`) pass through unchanged.
///   2. Empty string → `''`.
///   3. Contains whitespace but no single-quote → wrap in single-quotes.
///   4. Contains a single-quote (possibly with other specials) → wrap in
///      double-quotes. Double-quotes and backslashes inside are not escaped
///      (shell-quote doesn't encounter them in practice for its use cases).
///   5. Special shell chars (`$`, `&`, `;`, `|`, `>`, `<`, `*`, `?`, `!`)
///      without whitespace or single-quote → backslash-escape each special char.
///
/// PowerShell quoting uses double-quotes with backtick escapes.

import Foundation

// MARK: - ShellQuoting

public enum ShellQuoting {

    // MARK: Bash

    /// Joins an array of arguments into a single shell-quoted Bash command string.
    ///
    /// ```swift
    /// ShellQuoting.bashQuote(["echo", "hello world"])  // "echo 'hello world'"
    /// ShellQuoting.bashQuote(["echo", "it's"])         // "echo \"it's\""
    /// ```
    public static func bashQuote(_ args: [String]) -> String {
        args.map { bashEscape($0) }.joined(separator: " ")
    }

    /// Escapes a single Bash argument, matching the behavior of the `shell-quote`
    /// npm package used by the reference TypeScript source.
    public static func bashEscape(_ arg: String) -> String {
        // Empty string must be quoted
        if arg.isEmpty { return "''" }

        // If every character is "safe", no quoting needed
        if arg.unicodeScalars.allSatisfy({ bashSafeChar($0) }) {
            return arg
        }

        // If the token contains a single-quote → wrap in double-quotes
        // (shell-quote's strategy for single-quote-containing tokens)
        if arg.contains("'") {
            return "\"\(arg)\""
        }

        // If the token contains whitespace → wrap in single-quotes
        if arg.unicodeScalars.contains(where: { CharacterSet.whitespaces.contains($0) }) {
            return "'\(arg)'"
        }

        // Otherwise: backslash-escape each special character individually
        var result = ""
        result.reserveCapacity(arg.count * 2)
        for ch in arg {
            if bashSpecialChar(ch) {
                result.append("\\")
            }
            result.append(ch)
        }
        return result
    }

    // MARK: PowerShell

    /// Joins an array of arguments into a PowerShell command string.
    public static func powershellQuote(_ args: [String]) -> String {
        args.map { powershellEscape($0) }.joined(separator: " ")
    }

    /// Escapes a single PowerShell argument.
    ///
    /// PowerShell uses double-quoted strings where `"` → `` `" `` and
    /// `` ` `` → ```` `` ````.
    public static func powershellEscape(_ arg: String) -> String {
        if arg.isEmpty { return "''" }

        // Safe tokens pass through unchanged
        if arg.unicodeScalars.allSatisfy({ powershellSafeChar($0) }) {
            return arg
        }

        // Escape backtick then double-quote, then dollar, then wrap
        var escaped = arg
        escaped = escaped.replacingOccurrences(of: "`", with: "``")
        escaped = escaped.replacingOccurrences(of: "\"", with: "`\"")
        escaped = escaped.replacingOccurrences(of: "$", with: "`$")
        return "\"\(escaped)\""
    }

    // MARK: Private helpers

    /// Returns `true` for characters that are safe to use unquoted in Bash.
    ///
    /// Matches the `shell-quote` npm package's safe-char definition:
    /// alphanumeric + `@%+=:,./-_`
    private static func bashSafeChar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        // A-Z, a-z, 0-9
        case 0x41...0x5A, 0x61...0x7A, 0x30...0x39:
            return true
        // @ % + = : , . / - _
        case 0x40, 0x25, 0x2B, 0x3D, 0x3A, 0x2C, 0x2E, 0x2F, 0x2D, 0x5F:
            return true
        default:
            return false
        }
    }

    /// Returns `true` if a character needs a backslash escape in Bash (when not quoting).
    private static func bashSpecialChar(_ ch: Character) -> Bool {
        switch ch {
        case "$", "&", ";", "|", ">", "<", "*", "?", "!", "(", ")", "{", "}",
             "[", "]", "#", "~", "\\", "\"", "'", "`", " ", "\t", "\n":
            return true
        default:
            return false
        }
    }

    /// Returns `true` for characters that are safe to use unquoted in PowerShell.
    private static func powershellSafeChar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        // A-Z, a-z, 0-9
        case 0x41...0x5A, 0x61...0x7A, 0x30...0x39:
            return true
        // _ - . / : (: for Windows drive letters like C:\foo)
        case 0x5F, 0x2D, 0x2E, 0x2F, 0x3A:
            return true
        // Backslash (common in Windows paths like C:\foo)
        case 0x5C:
            return true
        default:
            return false
        }
    }
}
