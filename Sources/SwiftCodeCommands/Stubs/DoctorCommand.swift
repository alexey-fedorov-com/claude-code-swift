import SwiftCodeCore
public struct DoctorCommand: SlashCommand {
    public let name = "doctor"
    public let description = "Run diagnostic checks on the Claude Code installation"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'doctor' is not yet implemented in Swift Code.")
    }
}
