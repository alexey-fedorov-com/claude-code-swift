import SwiftCodeCore
public struct LogoutCommand: SlashCommand {
    public let name = "logout"
    public let description = "Log out of your Anthropic account"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'logout' is not yet implemented in Swift Code.")
    }
}
