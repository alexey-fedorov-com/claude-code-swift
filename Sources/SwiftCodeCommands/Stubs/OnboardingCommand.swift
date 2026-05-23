import SwiftCodeCore
public struct OnboardingCommand: SlashCommand {
    public let name = "onboarding"
    public let description = "Run the onboarding flow (Anthropic internal)"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'onboarding' is not yet implemented in Swift Code.")
    }
}
