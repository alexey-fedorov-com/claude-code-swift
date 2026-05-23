import SwiftCodeCore
public struct VoiceCommand: SlashCommand {
    public let name = "voice"
    public let description = "Toggle voice mode"
    public let requiredFeatureFlag: FeatureFlag? = .voiceMode
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'voice' is not yet implemented in Swift Code.")
    }
}
