import SwiftCodeCore
public struct ReleaseNotesCommand: SlashCommand {
    public let name = "release-notes"
    public let description = "Show the latest release notes"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'release-notes' is not yet implemented in Swift Code.")
    }
}
