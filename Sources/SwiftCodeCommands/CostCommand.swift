import SwiftCodeCore
import SwiftCodeAPI
import Foundation

// MARK: - CostCommand
// Mirrors: .reference/src/commands/cost/

/// Show accumulated API cost for the current session.
///
/// Reads from the `CostTracker` in `SlashCommandContext`. If no tracker is
/// present (e.g., a test context), reports $0.00.
public struct CostCommand: SlashCommand {
    public let name = "cost"
    public let description = "Show session cost and token usage"
    public let aliases: [String] = []
    public let isHidden = false
    public let supportsNonInteractive = true

    public init() {}

    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        guard let tracker = context.costTracker else {
            return .message("Session cost: $0.00 (no cost tracker attached)")
        }

        let total = await tracker.totalUSD()
        let breakdown = await tracker.breakdown()
        let unknownCost = await tracker.unknownModelCostDetected()

        var lines: [String] = []
        lines.append("Session cost: \(CostFormatter.format(total))")

        if !breakdown.isEmpty {
            lines.append("")
            lines.append("Breakdown by model:")
            let sorted = breakdown.sorted { $0.key < $1.key }
            for (modelId, entry) in sorted {
                let name = ModelRegistry.resolve(modelId)?.displayName ?? modelId
                lines.append("  \(name): \(CostFormatter.format(entry.cost))  (\(entry.tokens) tokens)")
            }
        }

        if unknownCost {
            lines.append("")
            lines.append("Note: some models had unknown pricing — cost may be underestimated.")
        }

        return .message(lines.joined(separator: "\n"))
    }
}
