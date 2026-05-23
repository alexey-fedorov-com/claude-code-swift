import SwiftCodeCore
public struct TeleportCommand: SlashCommand {
    public let name = "teleport"
    public let description = "Teleport to a different session (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'teleport' is not yet implemented in Swift Code.")
    }
}
