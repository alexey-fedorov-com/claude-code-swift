import SwiftCodeCore
public struct SessionCommand: SlashCommand {
    public let name = "session"
    public let description = "Manage sessions and view session QR code"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'session' is not yet implemented in Swift Code.")
    }
}
