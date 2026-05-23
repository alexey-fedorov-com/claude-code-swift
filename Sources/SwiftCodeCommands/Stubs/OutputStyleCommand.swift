import SwiftCodeCore
public struct OutputStyleCommand: SlashCommand {
    public let name = "output-style"
    public let description = "Set the output formatting style"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'output-style' is not yet implemented in Swift Code.")
    }
}
