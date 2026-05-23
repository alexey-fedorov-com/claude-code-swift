import SwiftCodeCore
public struct SummaryCommand: SlashCommand {
    public let name = "summary"
    public let description = "Summarize the conversation (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'summary' is not yet implemented in Swift Code.")
    }
}
