import SwiftCodeCore
public struct HooksCommand: SlashCommand {
    public let name = "hooks"
    public let description = "Manage Claude Code hooks"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'hooks' is not yet implemented in Swift Code.")
    }
}
