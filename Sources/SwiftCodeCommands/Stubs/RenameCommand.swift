import SwiftCodeCore
public struct RenameCommand: SlashCommand {
    public let name = "rename"
    public let description = "Rename the current session"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'rename' is not yet implemented in Swift Code.")
    }
}
