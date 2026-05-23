import SwiftCodeCore
public struct MobileCommand: SlashCommand {
    public let name = "mobile"
    public let description = "Connect from a mobile device via QR code"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'mobile' is not yet implemented in Swift Code.")
    }
}
