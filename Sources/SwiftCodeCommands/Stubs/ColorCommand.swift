import SwiftCodeCore
public struct ColorCommand: SlashCommand {
    public let name = "color"
    public let description = "Change the agent color scheme"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'color' is not yet implemented in Swift Code.")
    }
}
