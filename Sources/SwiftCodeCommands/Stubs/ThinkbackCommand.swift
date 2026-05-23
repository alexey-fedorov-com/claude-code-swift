import SwiftCodeCore
public struct ThinkbackCommand: SlashCommand {
    public let name = "thinkback"
    public let description = "Review previous thinking steps"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'thinkback' is not yet implemented in Swift Code.")
    }
}
