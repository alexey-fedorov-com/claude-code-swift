import SwiftCodeCore
public struct CtxVizCommand: SlashCommand {
    public let name = "ctx_viz"
    public let description = "Visualize context usage (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'ctx_viz' is not yet implemented in Swift Code.")
    }
}
