import SwiftCodeCore
import SwiftCodeAPI

public struct LoginCommand: SlashCommand {
    public let name = "login"
    public let description = "Sign in to Anthropic (API key or browser OAuth)"
    public init() {}

    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        return .showLoginFlow
    }
}
