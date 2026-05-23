import SwiftCodeCore
public struct TagCommand: SlashCommand {
    public let name = "tag"
    public let description = "Tag the current conversation"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'tag' is not yet implemented in Swift Code.")
    }
}
