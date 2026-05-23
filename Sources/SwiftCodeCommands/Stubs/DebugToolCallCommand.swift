import SwiftCodeCore
public struct DebugToolCallCommand: SlashCommand {
    public let name = "debug-tool-call"
    public let description = "Debug a tool call (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'debug-tool-call' is not yet implemented in Swift Code.")
    }
}
