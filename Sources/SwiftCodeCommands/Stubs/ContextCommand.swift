import SwiftCodeCore
public struct ContextCommand: SlashCommand {
    public let name = "context"
    public let description = "Show or set context for the conversation"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'context' is not yet implemented in Swift Code.")
    }
}
