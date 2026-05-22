// MARK: - CommandContracts
// Ported from .reference/src/types/command.ts
//
// React-specific types (LocalJSXCommand, LocalJSXCommandCall, etc.) are
// reduced to their data-shape equivalents. Async closures retain their
// signatures but drop the React.ReactNode return — those live in Task 10/14.

// MARK: - CommandAvailability

/// Which auth/provider environments a command is available in.
/// Mirrors TypeScript `CommandAvailability`.
public enum CommandAvailability: String, Sendable {
    case claudeAI = "claude-ai"
    case console
}

// MARK: - CommandResultDisplay

public enum CommandResultDisplay: String, Sendable {
    case skip, system, user
}

// MARK: - LocalCommandResult

/// Result of executing a local command.
/// Mirrors TypeScript `LocalCommandResult`.
public enum LocalCommandResult: Sendable {
    case text(String)
    /// TODO: CompactionResult port in Task 12
    case compact(displayText: String?)
    case skip
}

// MARK: - ResumeEntrypoint

public enum ResumeEntrypoint: String, Sendable {
    case cliFlag = "cli_flag"
    case slashCommandPicker = "slash_command_picker"
    case slashCommandSessionId = "slash_command_session_id"
    case slashCommandTitle = "slash_command_title"
    case fork
}

// MARK: - CommandBase

/// Common fields on every command. Mirrors TypeScript `CommandBase`.
public struct CommandBase: Sendable {
    public var name: String
    public var description: String
    public var aliases: [String]
    public var availability: [CommandAvailability]?
    public var isHidden: Bool
    public var isMcp: Bool
    public var argumentHint: String?
    public var whenToUse: String?
    public var version: String?
    public var disableModelInvocation: Bool
    public var userInvocable: Bool?
    public var loadedFrom: LoadedFrom?
    public var kind: CommandKind?
    public var immediate: Bool
    public var isSensitive: Bool
    public var hasUserSpecifiedDescription: Bool
    public var isEnabled: (@Sendable () -> Bool)?
    public var userFacingName: (@Sendable () -> String)?

    public enum LoadedFrom: String, Sendable {
        case commandsDeprecated = "commands_DEPRECATED"
        case skills
        case plugin
        case managed
        case bundled
        case mcp
    }

    public enum CommandKind: String, Sendable {
        case workflow
    }

    public init(
        name: String,
        description: String,
        aliases: [String] = [],
        availability: [CommandAvailability]? = nil,
        isHidden: Bool = false,
        isMcp: Bool = false,
        argumentHint: String? = nil,
        whenToUse: String? = nil,
        version: String? = nil,
        disableModelInvocation: Bool = false,
        userInvocable: Bool? = nil,
        loadedFrom: LoadedFrom? = nil,
        kind: CommandKind? = nil,
        immediate: Bool = false,
        isSensitive: Bool = false,
        hasUserSpecifiedDescription: Bool = false,
        isEnabled: (@Sendable () -> Bool)? = nil,
        userFacingName: (@Sendable () -> String)? = nil
    ) {
        self.name = name
        self.description = description
        self.aliases = aliases
        self.availability = availability
        self.isHidden = isHidden
        self.isMcp = isMcp
        self.argumentHint = argumentHint
        self.whenToUse = whenToUse
        self.version = version
        self.disableModelInvocation = disableModelInvocation
        self.userInvocable = userInvocable
        self.loadedFrom = loadedFrom
        self.kind = kind
        self.immediate = immediate
        self.isSensitive = isSensitive
        self.hasUserSpecifiedDescription = hasUserSpecifiedDescription
        self.isEnabled = isEnabled
        self.userFacingName = userFacingName
    }

    /// Resolved user-visible name, falling back to `name`.
    public func resolvedUserFacingName() -> String {
        userFacingName?() ?? name
    }

    /// Resolved enabled state, defaulting to true.
    public func resolvedIsEnabled() -> Bool {
        isEnabled?() ?? true
    }
}

// MARK: - CommandKind (command type)

/// The execution strategy for a command.
public enum CommandType: Sendable {
    /// Expands a prompt template into the conversation.
    case prompt(PromptCommandData)
    /// Runs a local Swift function.
    case local(LocalCommandData)
}

public struct PromptCommandData: Sendable {
    public var progressMessage: String
    public var contentLength: Int
    public var argNames: [String]?
    public var allowedTools: [String]?
    public var model: String?
    public var source: String
    public var context: SkillContext
    public var agent: String?
    public var paths: [String]?

    public enum SkillContext: String, Sendable {
        case inline, fork
    }

    public init(
        progressMessage: String,
        contentLength: Int,
        argNames: [String]? = nil,
        allowedTools: [String]? = nil,
        model: String? = nil,
        source: String,
        context: SkillContext = .inline,
        agent: String? = nil,
        paths: [String]? = nil
    ) {
        self.progressMessage = progressMessage
        self.contentLength = contentLength
        self.argNames = argNames
        self.allowedTools = allowedTools
        self.model = model
        self.source = source
        self.context = context
        self.agent = agent
        self.paths = paths
    }
}

public struct LocalCommandData: Sendable {
    public var supportsNonInteractive: Bool
    public var call: @Sendable (String, ToolUseContext) async throws -> LocalCommandResult

    public init(
        supportsNonInteractive: Bool,
        call: @escaping @Sendable (String, ToolUseContext) async throws -> LocalCommandResult
    ) {
        self.supportsNonInteractive = supportsNonInteractive
        self.call = call
    }
}

// MARK: - Command

/// A fully-resolved command. Combines CommandBase + one CommandType.
public struct Command: Sendable {
    public var base: CommandBase
    public var type: CommandType

    public init(base: CommandBase, type: CommandType) {
        self.base = base
        self.type = type
    }

    public var name: String { base.name }
    public var description: String { base.description }

    public func resolvedUserFacingName() -> String { base.resolvedUserFacingName() }
    public func resolvedIsEnabled() -> Bool { base.resolvedIsEnabled() }
}
