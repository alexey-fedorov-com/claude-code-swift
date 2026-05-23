import SwiftCodeCore
public struct FeedbackCommand: SlashCommand {
    public let name = "feedback"
    public let description = "Send feedback to Anthropic"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'feedback' is not yet implemented in Swift Code.")
    }
}
