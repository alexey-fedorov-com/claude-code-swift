import SwiftCodeCore
public struct ReloadPluginsCommand: SlashCommand {
    public let name = "reload-plugins"
    public let description = "Reload all plugins from disk"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'reload-plugins' is not yet implemented in Swift Code.")
    }
}
