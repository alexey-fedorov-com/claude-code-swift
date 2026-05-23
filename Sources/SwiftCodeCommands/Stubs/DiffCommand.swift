import SwiftCodeCore
public struct DiffCommand: SlashCommand {
    public let name = "diff"
    public let description = "Show git diff for recent changes"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'diff' is not yet implemented in Swift Code.")
    }
}
