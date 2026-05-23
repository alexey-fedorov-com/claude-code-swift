import SwiftCodeCore
import SwiftCodeAPI
import Foundation

// MARK: - StatusCommand
// Mirrors: .reference/src/commands/status/

/// Print a summary of the current session environment.
///
/// Shows: working directory, active model, session ID, feature flags that are
/// on, and whether running as ant-user / demo mode.
public struct StatusCommand: SlashCommand {
    public let name = "status"
    public let description = "Show session status and environment"
    public let aliases: [String] = []
    public let isHidden = false
    public let supportsNonInteractive = true

    public init() {}

    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        let model = context.currentModel.flatMap { ModelRegistry.resolve($0)?.displayName }
                    ?? ModelRegistry.defaultMainLoopModel.displayName
        let cwd = context.workingDirectory.path
        let session = context.sessionId.isEmpty ? "(none)" : context.sessionId
        let userType = context.isAntUser ? "ant" : "external"
        let demo = context.isDemoMode ? " (demo)" : ""

        let activeFlags = FeatureFlag.allCases.filter { context.isFeatureEnabled($0) }
        let flagDesc = activeFlags.isEmpty
            ? "none"
            : activeFlags.map { $0.rawValue }.sorted().joined(separator: ", ")

        let lines = [
            "Claude Code — session status",
            "  model:      \(model)",
            "  cwd:        \(cwd)",
            "  session:    \(session)",
            "  user type:  \(userType)\(demo)",
            "  flags:      \(flagDesc)",
        ]
        return .message(lines.joined(separator: "\n"))
    }
}
