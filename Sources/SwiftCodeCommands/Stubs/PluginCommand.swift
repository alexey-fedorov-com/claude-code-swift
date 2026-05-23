import SwiftCodeCore
public struct PluginCommand: SlashCommand {
    public let name = "plugin"
    public let description = "Manage Claude Code plugins"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'plugin' is not yet implemented in Swift Code.")
    }
}
