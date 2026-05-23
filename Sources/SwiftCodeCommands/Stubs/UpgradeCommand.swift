import SwiftCodeCore
public struct UpgradeCommand: SlashCommand {
    public let name = "upgrade"
    public let description = "Upgrade Claude Code to the latest version"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'upgrade' is not yet implemented in Swift Code.")
    }
}
