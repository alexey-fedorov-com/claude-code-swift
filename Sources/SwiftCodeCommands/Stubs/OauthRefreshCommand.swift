import SwiftCodeCore
public struct OauthRefreshCommand: SlashCommand {
    public let name = "oauth-refresh"
    public let description = "Force OAuth token refresh (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'oauth-refresh' is not yet implemented in Swift Code.")
    }
}
