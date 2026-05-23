import SwiftCodeCore
public struct ThemeCommand: SlashCommand {
    public let name = "theme"
    public let description = "Change the terminal color theme"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'theme' is not yet implemented in Swift Code.")
    }
}
