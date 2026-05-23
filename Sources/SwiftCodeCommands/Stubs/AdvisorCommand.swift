import SwiftCodeCore
public struct AdvisorCommand: SlashCommand {
    public let name = "advisor"
    public let description = "Get advice on how to use Claude Code effectively"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'advisor' is not yet implemented in Swift Code.")
    }
}
