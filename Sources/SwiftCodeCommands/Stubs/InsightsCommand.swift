import SwiftCodeCore
public struct InsightsCommand: SlashCommand {
    public let name = "insights"
    public let description = "View usage insights (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'insights' is not yet implemented in Swift Code.")
    }
}
