import SwiftCodeCore
public struct ReviewCommand: SlashCommand {
    public let name = "review"
    public let description = "Review code changes or a pull request"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'review' is not yet implemented in Swift Code.")
    }
}
