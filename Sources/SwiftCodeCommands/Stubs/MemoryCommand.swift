import SwiftCodeCore
public struct MemoryCommand: SlashCommand {
    public let name = "memory"
    public let description = "Manage Claude Code memory and context files"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'memory' is not yet implemented in Swift Code.")
    }
}
