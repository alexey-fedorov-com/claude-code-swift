import SwiftCodeCore
public struct SecurityReviewCommand: SlashCommand {
    public let name = "security-review"
    public let description = "Run a security review of the codebase"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'security-review' is not yet implemented in Swift Code.")
    }
}
