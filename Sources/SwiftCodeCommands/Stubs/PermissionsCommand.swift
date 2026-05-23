import SwiftCodeCore
public struct PermissionsCommand: SlashCommand {
    public let name = "permissions"
    public let description = "View and manage tool permissions"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'permissions' is not yet implemented in Swift Code.")
    }
}
