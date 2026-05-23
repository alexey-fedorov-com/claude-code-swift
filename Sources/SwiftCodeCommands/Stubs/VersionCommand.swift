import SwiftCodeCore
public struct VersionCommand: SlashCommand {
    public let name = "version"
    public let description = "Show the Claude Code version (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'version' is not yet implemented in Swift Code.")
    }
}
