import SwiftCodeCore
public struct BranchCommand: SlashCommand {
    public let name = "branch"
    public let description = "Manage git branches"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'branch' is not yet implemented in Swift Code.")
    }
}
