import SwiftCodeCore
public struct GoodClaudeCommand: SlashCommand {
    public let name = "good-claude"
    public let description = "Acknowledge good Claude behavior (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'good-claude' is not yet implemented in Swift Code.")
    }
}
