import SwiftCodeCore
public struct RewindCommand: SlashCommand {
    public let name = "rewind"
    public let description = "Rewind the conversation to a previous state"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'rewind' is not yet implemented in Swift Code.")
    }
}
