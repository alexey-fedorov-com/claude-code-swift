import SwiftCodeCore
public struct CopyCommand: SlashCommand {
    public let name = "copy"
    public let description = "Copy last response to clipboard"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'copy' is not yet implemented in Swift Code.")
    }
}
