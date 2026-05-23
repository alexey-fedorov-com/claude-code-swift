import SwiftCodeCore
import SwiftCodeAPI
import Foundation

// MARK: - ConfigCommand
// Mirrors: .reference/src/commands/config/

/// Display or modify Claude Code settings.
///
/// Without arguments: prints a summary of key settings.
/// With `<key> <value>`: sets the named setting (writes to user settings.json).
///
/// NOTE: Full settings write-through requires the SettingsLoader from Task 7.
/// This implementation prints a read-only summary; write support is scaffolded
/// with a TODO for when the loader is wired in.
public struct ConfigCommand: SlashCommand {
    public let name = "config"
    public let description = "View and modify configuration"
    public let aliases: [String] = []
    public let isHidden = false
    public let supportsNonInteractive = true

    public init() {}

    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        let arg = input.trimmingCharacters(in: .whitespaces)

        if arg.isEmpty {
            return printConfig(context: context)
        }

        // Parse "key value" pair
        let parts = arg.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return .message("""
                Usage:
                  /config              — show current config
                  /config <key> <val>  — set a config value

                Settable keys: model, theme, verbose, showThinkingSummaries, autoCompactEnabled
                """)
        }

        let key = parts[0]
        let value = parts[1]

        // TODO (Task 7/15): wire up SettingsLoader to persist changes
        return .message("Would set \(key) = \(value) (settings write not yet wired — rebuild after Task 15).")
    }

    private func printConfig(context: SlashCommandContext) -> SlashCommandResult {
        let model = context.currentModel ?? ModelRegistry.defaultMainLoopModel.id
        let cwd = context.workingDirectory.path
        let flagLines = FeatureFlag.allCases.compactMap { flag -> String? in
            let on = context.isFeatureEnabled(flag)
            guard on else { return nil }
            return "  \(flag.rawValue): enabled"
        }

        var lines = [
            "Claude Code — current configuration",
            "  model:   \(model)",
            "  cwd:     \(cwd)",
            "  session: \(context.sessionId.isEmpty ? "(none)" : context.sessionId)",
        ]
        if !flagLines.isEmpty {
            lines.append("  active feature flags:")
            lines.append(contentsOf: flagLines)
        }
        return .message(lines.joined(separator: "\n"))
    }
}
