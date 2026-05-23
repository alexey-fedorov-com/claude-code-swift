import SwiftCodeCore
public struct ShareCommand: SlashCommand {
    public let name = "share"
    public let description = "Share the conversation (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'share' is not yet implemented in Swift Code.")
    }
}
