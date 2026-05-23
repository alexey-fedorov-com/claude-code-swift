import SwiftCodeCore
public struct DesktopCommand: SlashCommand {
    public let name = "desktop"
    public let description = "Open Claude Code desktop integration"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'desktop' is not yet implemented in Swift Code.")
    }
}
