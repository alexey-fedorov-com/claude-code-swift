import SwiftCodeCore
public struct TerminalSetupCommand: SlashCommand {
    public let name = "terminalSetup"
    public let description = "Configure terminal settings for Claude Code"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'terminalSetup' is not yet implemented in Swift Code.")
    }
}
