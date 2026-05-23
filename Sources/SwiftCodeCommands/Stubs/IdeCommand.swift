import SwiftCodeCore
public struct IdeCommand: SlashCommand {
    public let name = "ide"
    public let description = "Open the IDE integration"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'ide' is not yet implemented in Swift Code.")
    }
}
