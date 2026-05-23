import SwiftCodeCore
public struct BriefCommand: SlashCommand {
    public let name = "brief"
    public let description = "Show a brief summary (Kairos)"
    public let requiredFeatureFlag: FeatureFlag? = .kairosBrief
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'brief' is not yet implemented in Swift Code.")
    }
}
