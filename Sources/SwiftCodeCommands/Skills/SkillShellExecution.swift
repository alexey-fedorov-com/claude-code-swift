/// SkillShellExecution — `!`cmd`` and ` ```! ``` ` expansion + disableSkillShellExecution gating.
///
/// 2.1.91 backport: "disableSkillShellExecution setting — disables !`cmd` and ```!```
/// shell execution in skills/commands/plugins."
///
/// Mirrors .reference/src/utils/promptShellExecution.ts.
///
/// When `allowExecution == false` (i.e. disableSkillShellExecution = true in settings),
/// shell patterns are preserved as-is (stripped from the body without execution).
/// When `allowExecution == true`, they are expanded by running the command.

import Foundation
import SwiftCodeNative

// MARK: - SkillShellExecution

public enum SkillShellExecution {
    // MARK: - Patterns

    /// Inline backtick shell execution: `` !`command` ``
    static let inlinePattern = #"!`([^`]+)`"#

    /// Fenced code block shell execution:
    /// ```!
    /// command
    /// ```
    static let fencedPattern = #"```!\n([\s\S]*?)```"#

    // MARK: - Errors

    public enum ExpansionError: Error, LocalizedError {
        case commandFailed(command: String, exitCode: Int32, stderr: String)
        case patternError(String)

        public var errorDescription: String? {
            switch self {
            case .commandFailed(let cmd, let code, let err):
                return "Shell command '\(cmd)' failed (exit \(code)): \(err)"
            case .patternError(let msg):
                return "Shell expansion pattern error: \(msg)"
            }
        }
    }

    // MARK: - Expand

    /// Expands shell execution patterns in a skill body.
    ///
    /// - Parameters:
    ///   - body: The skill/SKILL.md body text.
    ///   - allowExecution: When `false`, patterns are removed without execution
    ///     (respects `disableSkillShellExecution` setting). When `true`, commands run.
    ///   - processRunner: The process runner for executing commands.
    /// - Returns: The body with shell patterns expanded (or removed).
    public static func expand(
        _ body: String,
        allowExecution: Bool,
        processRunner: ProcessRunner
    ) async throws -> String {
        var result = body

        // Expand fenced blocks first (they may contain newlines)
        result = try await expandFenced(result, allowExecution: allowExecution, processRunner: processRunner)

        // Then expand inline backtick patterns
        result = try await expandInline(result, allowExecution: allowExecution, processRunner: processRunner)

        return result
    }

    // MARK: - Private

    private static func expandFenced(
        _ text: String,
        allowExecution: Bool,
        processRunner: ProcessRunner
    ) async throws -> String {
        guard let regex = try? NSRegularExpression(
            pattern: fencedPattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            throw ExpansionError.patternError("Failed to compile fenced block regex")
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)

        // Process matches in reverse to preserve indices
        var result = text
        for match in matches.reversed() {
            let commandRange = match.range(at: 1)
            let command = nsText.substring(with: commandRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !allowExecution {
                // Remove the block
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
                continue
            }

            let output = try await runCommand(command, processRunner: processRunner)
            result = (result as NSString).replacingCharacters(in: match.range, with: output)
        }

        return result
    }

    private static func expandInline(
        _ text: String,
        allowExecution: Bool,
        processRunner: ProcessRunner
    ) async throws -> String {
        guard let regex = try? NSRegularExpression(pattern: inlinePattern, options: []) else {
            throw ExpansionError.patternError("Failed to compile inline regex")
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)

        var result = text
        for match in matches.reversed() {
            let commandRange = match.range(at: 1)
            let command = nsText.substring(with: commandRange)

            if !allowExecution {
                // Remove the pattern
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
                continue
            }

            let output = try await runCommand(command, processRunner: processRunner)
            // Inline replacement: strip trailing newline
            let inline = output.trimmingCharacters(in: .newlines)
            result = (result as NSString).replacingCharacters(in: match.range, with: inline)
        }

        return result
    }

    private static func runCommand(
        _ command: String,
        processRunner: ProcessRunner
    ) async throws -> String {
        let result = try await processRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", command]
        )

        if result.exitCode != 0 {
            throw ExpansionError.commandFailed(
                command: command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return result.stdout
    }
}
