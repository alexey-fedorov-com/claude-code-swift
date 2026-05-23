import SwiftCodeCore
import Foundation

// MARK: - HelpCommand
// Mirrors: .reference/src/commands/help/

/// List all available slash commands with their descriptions.
/// Respects ant-user and feature-flag visibility the same way `CommandRegistry`
/// does so the output matches what's actually usable.
public struct HelpCommand: SlashCommand {
    public let name = "help"
    public let description = "Show help and available commands"
    public let aliases: [String] = []
    public let isHidden = false

    public init() {}

    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        let registry = CommandRegistry.defaultRegistry()
        // Give the actor a moment to finish registering (Task-based init)
        try? await Task.sleep(nanoseconds: 1_000_000)

        let available = await registry.availableCommands(
            antUser: context.isAntUser,
            demoMode: context.isDemoMode
        )

        let visible = available.filter { !$0.isHidden }.sorted { $0.name < $1.name }

        var lines: [String] = []
        lines.append("Available slash commands:")
        lines.append("")

        let maxLen = visible.map { $0.name.count }.max() ?? 0

        for cmd in visible {
            let padding = String(repeating: " ", count: maxLen - cmd.name.count)
            var line = "  /\(cmd.name)\(padding)  \(cmd.description)"
            if !cmd.aliases.isEmpty {
                line += "  (aliases: \(cmd.aliases.map { "/\($0)" }.joined(separator: ", ")))"
            }
            lines.append(line)
        }

        lines.append("")
        lines.append("Type /<command> to run. Add arguments after the command name.")

        return .message(lines.joined(separator: "\n"))
    }
}
