import SwiftCodeCore
public struct ExportCommand: SlashCommand {
    public let name = "export"
    public let description = "Export the conversation to a file"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'export' is not yet implemented in Swift Code.")
    }
}
