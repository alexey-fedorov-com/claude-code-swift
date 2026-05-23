import SwiftCodeCore
public struct LoginCommand: SlashCommand {
    public let name = "login"
    public let description = "Log in to your Anthropic account"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'login' is not yet implemented in Swift Code.")
    }
}
