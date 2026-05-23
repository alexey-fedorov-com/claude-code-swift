import SwiftCodeCore
public struct PrCommentsCommand: SlashCommand {
    public let name = "pr_comments"
    public let description = "Fetch and show PR review comments"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'pr_comments' is not yet implemented in Swift Code.")
    }
}
