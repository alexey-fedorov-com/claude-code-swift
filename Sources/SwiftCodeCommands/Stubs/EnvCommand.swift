import SwiftCodeCore
public struct EnvCommand: SlashCommand {
    public let name = "env"
    public let description = "Show environment variables (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'env' is not yet implemented in Swift Code.")
    }
}
