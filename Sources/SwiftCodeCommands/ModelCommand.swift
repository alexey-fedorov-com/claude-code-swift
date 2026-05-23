import SwiftCodeCore
import SwiftCodeAPI
import Foundation

// MARK: - ModelCommand
// Mirrors: .reference/src/commands/model/

/// Print or change the active AI model.
///
/// Without arguments: prints the current model.
/// With an argument:  validates the alias/ID against `ModelRegistry` and returns
///                    `.setModel(_:)` so the REPL can update session state.
public struct ModelCommand: SlashCommand {
    public let name = "model"
    public let aliases: [String] = []
    public let isHidden = false
    public let supportsNonInteractive = true

    public var description: String {
        let current = ModelRegistry.defaultMainLoopModel.displayName
        return "Set the AI model (currently \(current))"
    }

    public init() {}

    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        let arg = input.trimmingCharacters(in: .whitespaces)

        if arg.isEmpty {
            // Print current model
            let modelId = context.currentModel ?? ModelRegistry.defaultMainLoopModel.id
            if let info = ModelRegistry.resolve(modelId) {
                let lines = [
                    "Current model: \(info.displayName) (\(info.id))",
                    "Context window: \(info.contextWindow / 1000)K tokens",
                    "Max output: \(info.maxOutputTokens) tokens",
                    "Cost: $\(info.inputCostPer1MTokens)/M input · $\(info.outputCostPer1MTokens)/M output",
                    "",
                    "Use /model <alias> to switch. Available aliases: opus, sonnet, haiku, best",
                ]
                return .message(lines.joined(separator: "\n"))
            } else {
                return .message("Current model: \(modelId) (unknown — not in registry)")
            }
        }

        // Validate the requested model
        if let info = ModelRegistry.resolve(arg) {
            return .setModel(info.id)
        }

        // Unknown model — list available
        let names = ModelRegistry.models.map { $0.id }.joined(separator: "\n  ")
        let msg = """
            Unknown model: '\(arg)'

            Available models:
              \(names)

            Aliases: opus, sonnet, haiku, best
            """
        return .message(msg)
    }
}
