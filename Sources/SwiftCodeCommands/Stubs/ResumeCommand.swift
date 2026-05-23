import SwiftCodeCore
public struct ResumeCommand: SlashCommand {
    public let name = "resume"
    public let description = "Resume a previous session"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'resume' is not yet implemented in Swift Code.")
    }
}
