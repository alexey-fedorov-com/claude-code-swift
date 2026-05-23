import SwiftCodeCore
public struct SandboxToggleCommand: SlashCommand {
    public let name = "sandbox-toggle"
    public let description = "Toggle sandbox mode for tool execution"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'sandbox-toggle' is not yet implemented in Swift Code.")
    }
}
