import SwiftCodeCore
public struct MockLimitsCommand: SlashCommand {
    public let name = "mock-limits"
    public let description = "Mock rate limits for testing (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'mock-limits' is not yet implemented in Swift Code.")
    }
}
