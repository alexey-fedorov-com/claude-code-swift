import SwiftCodeCore
public struct InitCommand: SlashCommand {
    public let name = "init"
    public let description = "Initialize Claude Code in this project"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'init' is not yet implemented in Swift Code.")
    }
}
