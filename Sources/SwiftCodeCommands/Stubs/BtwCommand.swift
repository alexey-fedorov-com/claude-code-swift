import SwiftCodeCore
public struct BtwCommand: SlashCommand {
    public let name = "btw"
    public let description = "Add a quick note or context to the conversation"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'btw' is not yet implemented in Swift Code.")
    }
}
