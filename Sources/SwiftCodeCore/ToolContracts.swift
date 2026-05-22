// MARK: - ToolContracts
// Ported from .reference/src/Tool.ts
//
// The TypeScript Tool<Input, Output, P> is a structural interface with many
// optional methods. In Swift we model the required surface as a protocol and
// provide a concrete ToolBase struct for common defaults.
//
// React-rendering methods (renderToolResultMessage, renderToolUseMessage, etc.)
// are intentionally omitted — those live in SwiftCodeTerminalUI.
//
// TODO: extend with reference members when porting later tasks:
//   - ToolUseContext (full) — Task 12
//   - ToolResult<T> — Task 12
//   - PermissionResult — Task 8
//   - validateInput / checkPermissions — Task 8
//   - toAutoClassifierInput — Task 8

// MARK: - ValidationResult

public enum ValidationResult: Sendable {
    case valid
    case invalid(message: String, errorCode: Int)
}

// MARK: - ToolInputJSONSchema

public typealias ToolInputJSONSchema = [String: JSONValue]

// MARK: - ThinkingConfig
// Ported from .reference/src/utils/thinking.ts ThinkingConfig

public enum ThinkingConfig: Sendable, Equatable {
    case adaptive
    case enabled(budgetTokens: Int)
    case disabled
}

// MARK: - QuerySource
// Ported from .reference/src/constants/querySource.ts (shape inferred from usage)

public enum QuerySource: String, Sendable {
    case cli
    case sdk
    case api
    case repl
    case background
    case webSearch = "web_search"
}

// MARK: - ToolUseContext (minimal)
// Full port in Task 12. Here we define the minimal shape needed by ToolContracts.

public struct ToolUseContext: Sendable {
    public var messages: [Message]
    public var agentId: AgentId?
    public var agentType: String?
    public var verbose: Bool
    public var isNonInteractiveSession: Bool

    public init(
        messages: [Message] = [],
        agentId: AgentId? = nil,
        agentType: String? = nil,
        verbose: Bool = false,
        isNonInteractiveSession: Bool = false
    ) {
        self.messages = messages
        self.agentId = agentId
        self.agentType = agentType
        self.verbose = verbose
        self.isNonInteractiveSession = isNonInteractiveSession
    }
}

// MARK: - Tool protocol

/// Swift protocol mirroring the TypeScript Tool<Input, Output, P> interface.
/// Only required/non-rendering members are included at this layer.
public protocol Tool: Sendable {
    /// Primary name used to look up the tool in the API call.
    var name: String { get }

    /// Optional alias names for backwards compatibility.
    var aliases: [String] { get }

    /// Maximum result size before persisting to disk.
    var maxResultSizeChars: Int { get }

    /// Whether the tool is currently enabled.
    func isEnabled() -> Bool

    /// Whether the tool is read-only for a given input (serialized as JSON).
    func isReadOnly(input: [String: JSONValue]) -> Bool

    /// Whether two inputs produce equivalent tool calls (for deduplication).
    func inputsEquivalent(a: [String: JSONValue], b: [String: JSONValue]) -> Bool

    /// Whether the tool is safe to run concurrently with other tools.
    func isConcurrencySafe(input: [String: JSONValue]) -> Bool

    /// Human-facing name, defaults to `name`.
    func userFacingName(input: [String: JSONValue]?) -> String

    /// Short description for ToolSearch keyword matching.
    var searchHint: String? { get }

    /// Whether this tool is an MCP tool.
    var isMcp: Bool { get }

    /// Whether this tool is an LSP tool.
    var isLsp: Bool { get }
}

// MARK: - Tool default implementations

public extension Tool {
    var aliases: [String] { [] }
    var maxResultSizeChars: Int { 200_000 }
    var searchHint: String? { nil }
    var isMcp: Bool { false }
    var isLsp: Bool { false }

    func isEnabled() -> Bool { true }
    func isReadOnly(input: [String: JSONValue]) -> Bool { false }
    func inputsEquivalent(a: [String: JSONValue], b: [String: JSONValue]) -> Bool { false }
    func isConcurrencySafe(input: [String: JSONValue]) -> Bool { false }
    func userFacingName(input: [String: JSONValue]?) -> String { name }
}

// MARK: - toolMatchesName

public func toolMatchesName(_ tool: any Tool, name: String) -> Bool {
    tool.name == name || tool.aliases.contains(name)
}

// MARK: - ToolPermissionRulesBySource (placeholder)
// Full port in Task 8.

public typealias ToolPermissionRulesBySource = [String: [String]]
