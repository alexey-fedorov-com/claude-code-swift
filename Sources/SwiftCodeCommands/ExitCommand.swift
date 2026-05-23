import SwiftCodeCore
import Foundation

// MARK: - ExitCommand
// Mirrors: .reference/src/commands/exit/ (referenced from commands.ts as `exit`)

/// Exit the Claude Code CLI session.
///
/// The reference uses `process.exit()` after optional teardown. The Swift port
/// returns `.exit(0)` and lets the REPL (Task 15) call `Foundation.exit`.
public struct ExitCommand: SlashCommand {
    public let name = "exit"
    public let description = "Exit Claude Code"
    public let aliases: [String] = ["quit", "q"]
    public let isHidden = false
    public let supportsNonInteractive = true

    public init() {}

    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        return .exit(0)
    }
}
