import SwiftCodeCore
public struct IssueCommand: SlashCommand {
    public let name = "issue"
    public let description = "File a GitHub issue (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'issue' is not yet implemented in Swift Code.")
    }
}
