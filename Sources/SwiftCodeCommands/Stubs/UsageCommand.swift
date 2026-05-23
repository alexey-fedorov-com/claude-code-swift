import SwiftCodeCore
public struct UsageCommand: SlashCommand {
    public let name = "usage"
    public let description = "Show detailed token usage and billing info"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'usage' is not yet implemented in Swift Code.")
    }
}
