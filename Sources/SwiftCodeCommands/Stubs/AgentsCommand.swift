import SwiftCodeCore
public struct AgentsCommand: SlashCommand {
    public let name = "agents"
    public let description = "Manage and view agents"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'agents' is not yet implemented in Swift Code.")
    }
}
