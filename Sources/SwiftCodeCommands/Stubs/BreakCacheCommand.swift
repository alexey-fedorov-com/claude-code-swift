import SwiftCodeCore
public struct BreakCacheCommand: SlashCommand {
    public let name = "break-cache"
    public let description = "Break the prompt cache (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'break-cache' is not yet implemented in Swift Code.")
    }
}
