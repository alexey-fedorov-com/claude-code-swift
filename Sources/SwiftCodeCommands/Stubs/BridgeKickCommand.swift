import SwiftCodeCore
public struct BridgeKickCommand: SlashCommand {
    public let name = "bridge-kick"
    public let description = "Kick the bridge connection (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'bridge-kick' is not yet implemented in Swift Code.")
    }
}
