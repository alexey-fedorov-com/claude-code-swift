import SwiftCodeCore
public struct CommitCommand: SlashCommand {
    public let name = "commit"
    public let description = "Commit staged changes (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'commit' is not yet implemented in Swift Code.")
    }
}
