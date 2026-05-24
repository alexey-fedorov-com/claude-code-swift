import SwiftCodeCore
import SwiftCodeAPI
import Foundation

// MARK: - SlashCommandContext

/// Execution context passed to each slash command.
/// Mirrors the REPL context available to TypeScript commands.
public struct SlashCommandContext: Sendable {
    /// Current session ID.
    public let sessionId: String
    /// Current working directory for the session.
    public let workingDirectory: URL
    /// Currently configured model (alias or canonical ID).
    public let currentModel: String?
    /// Whether the session is running as an Anthropic internal user.
    public let isAntUser: Bool
    /// Whether demo mode is active.
    public let isDemoMode: Bool
    /// Active feature flags snapshot.
    public let featureFlags: [FeatureFlag: Bool]
    /// Accumulated cost tracker for this session (optional — not all contexts have one).
    public let costTracker: CostTracker?

    public init(
        sessionId: String = "",
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        currentModel: String? = nil,
        isAntUser: Bool = false,
        isDemoMode: Bool = false,
        featureFlags: [FeatureFlag: Bool] = FeatureFlags.current,
        costTracker: CostTracker? = nil
    ) {
        self.sessionId = sessionId
        self.workingDirectory = workingDirectory
        self.currentModel = currentModel
        self.isAntUser = isAntUser
        self.isDemoMode = isDemoMode
        self.featureFlags = featureFlags
        self.costTracker = costTracker
    }

    /// Returns the value of a feature flag in this context.
    public func isFeatureEnabled(_ flag: FeatureFlag) -> Bool {
        featureFlags[flag] ?? false
    }
}

// MARK: - SlashCommandResult

/// Result produced by executing a slash command.
public enum SlashCommandResult: Sendable {
    /// Print a string to the terminal.
    case message(String)
    /// Inject text into the next user prompt sent to the model.
    case promptInjection(String)
    /// Exit the process with the given code.
    case exit(Int32)
    /// No output — command handled silently.
    case noop
    /// Clear the conversation context / transcript.
    case clearContext
    /// Switch the active model to the given alias or ID.
    case setModel(String)
    /// Open the interactive login flow (menu → API key or OAuth).
    case showLoginFlow
    /// Drop currently stored credentials and report status.
    case logoutCompleted(message: String)
}

// MARK: - SlashCommand Protocol

/// A slash command that can be registered with `CommandRegistry`.
///
/// Mirrors the `Command` union type from the TypeScript reference
/// (src/types/command.ts). The Swift version flattens the union into a single
/// protocol because Swift doesn't have discriminated unions.
public protocol SlashCommand: Sendable {
    /// Primary command name (without leading `/`).
    var name: String { get }
    /// Short description shown in `/help`.
    var description: String { get }
    /// Alternative names that resolve to this command.
    var aliases: [String] { get }
    /// Whether to hide from `/help` listings.
    var isHidden: Bool { get }
    /// Whether this command is restricted to Anthropic-internal users.
    var requiresAntUser: Bool { get }
    /// Feature flag that must be enabled for this command to appear.
    var requiredFeatureFlag: FeatureFlag? { get }
    /// Whether this command can run in non-interactive (pipe) mode.
    var supportsNonInteractive: Bool { get }

    /// Execute the command.
    /// - Parameters:
    ///   - input: Any text that followed the command name on the same line.
    ///   - context: Session context (model, CWD, flags, etc.).
    /// - Returns: A `SlashCommandResult` describing what the REPL should do next.
    func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult
}

// MARK: - Default Implementations

public extension SlashCommand {
    var aliases: [String] { [] }
    var isHidden: Bool { false }
    var requiresAntUser: Bool { false }
    var requiredFeatureFlag: FeatureFlag? { nil }
    var supportsNonInteractive: Bool { false }
}
