import SwiftCodeCore
public struct BuddyCommand: SlashCommand {
    public let name = "buddy"
    public let description = "Manage your coding buddy agent"
    public let requiredFeatureFlag: FeatureFlag? = .buddy
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'buddy' is not yet implemented in Swift Code.")
    }
}
