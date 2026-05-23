import SwiftCodeCore
public struct AntTraceCommand: SlashCommand {
    public let name = "ant-trace"
    public let description = "Trace Anthropic-internal debug info"
    public let requiresAntUser = true
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'ant-trace' is not yet implemented in Swift Code.")
    }
}
