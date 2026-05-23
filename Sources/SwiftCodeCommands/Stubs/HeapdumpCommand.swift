import SwiftCodeCore
public struct HeapdumpCommand: SlashCommand {
    public let name = "heapdump"
    public let description = "Generate a heap dump for debugging"
    public let isHidden = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'heapdump' is not yet implemented in Swift Code.")
    }
}
