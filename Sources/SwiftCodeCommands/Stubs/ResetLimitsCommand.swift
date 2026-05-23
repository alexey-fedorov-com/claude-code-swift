import SwiftCodeCore
public struct ResetLimitsCommand: SlashCommand {
    public let name = "reset-limits"
    public let description = "Reset rate limits (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'reset-limits' is not yet implemented in Swift Code.")
    }
}
