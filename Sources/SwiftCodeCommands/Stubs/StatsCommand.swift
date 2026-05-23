import SwiftCodeCore
public struct StatsCommand: SlashCommand {
    public let name = "stats"
    public let description = "Show session statistics"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'stats' is not yet implemented in Swift Code.")
    }
}
