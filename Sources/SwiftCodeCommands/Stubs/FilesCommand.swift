import SwiftCodeCore
public struct FilesCommand: SlashCommand {
    public let name = "files"
    public let description = "List files being tracked in this session"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'files' is not yet implemented in Swift Code.")
    }
}
