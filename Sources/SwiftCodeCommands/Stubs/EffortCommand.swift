import SwiftCodeCore
public struct EffortCommand: SlashCommand {
    public let name = "effort"
    public let description = "Set the thinking effort level"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'effort' is not yet implemented in Swift Code.")
    }
}
