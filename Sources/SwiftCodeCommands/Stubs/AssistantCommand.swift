import SwiftCodeCore
public struct AssistantCommand: SlashCommand {
    public let name = "assistant"
    public let description = "Open the assistant/install wizard"
    public let requiredFeatureFlag: FeatureFlag? = .kairos
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'assistant' is not yet implemented in Swift Code.")
    }
}
