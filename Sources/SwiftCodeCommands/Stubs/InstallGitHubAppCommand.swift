import SwiftCodeCore
public struct InstallGitHubAppCommand: SlashCommand {
    public let name = "install-github-app"
    public let description = "Install the Claude Code GitHub App"
    public init() {}
    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        .message("Command 'install-github-app' is not yet implemented in Swift Code.")
    }
}
