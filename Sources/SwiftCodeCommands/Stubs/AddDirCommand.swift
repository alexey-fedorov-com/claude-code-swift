import SwiftCodeCore
public struct AddDirCommand: SlashCommand {
    public let name = "add-dir"
    public let description = "Add additional working directories"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'add-dir' is not yet implemented in Swift Code.")
    }
}
