import SwiftCodeCore
public struct PerfIssueCommand: SlashCommand {
    public let name = "perf-issue"
    public let description = "Report a performance issue (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'perf-issue' is not yet implemented in Swift Code.")
    }
}
