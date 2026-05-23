import SwiftCodeCore
public struct CompactCommand: SlashCommand {
    public let name = "compact"
    public let description = "Compact the conversation to reduce context size"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'compact' is not yet implemented in Swift Code.")
    }
}
