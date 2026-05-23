import SwiftCodeCore
import Foundation

// MARK: - ClearCommand
// Mirrors: .reference/src/commands/clear/

/// Clear the conversation context / transcript.
///
/// In the reference implementation, `/clear` wipes the in-memory message history
/// and re-renders the REPL with a fresh transcript. The Swift port signals this
/// intent via `.clearContext`; the REPL is responsible for acting on it.
public struct ClearCommand: SlashCommand {
    public let name = "clear"
    public let description = "Clear conversation history and context"
    public let aliases: [String] = []
    public let isHidden = false
    public let supportsNonInteractive = true

    public init() {}

    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        return .clearContext
    }
}
