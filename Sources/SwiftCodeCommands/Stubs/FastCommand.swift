import SwiftCodeCore
public struct FastCommand: SlashCommand {
    public let name = "fast"
    public let description = "Toggle fast mode (reduced thinking)"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'fast' is not yet implemented in Swift Code.")
    }
}
