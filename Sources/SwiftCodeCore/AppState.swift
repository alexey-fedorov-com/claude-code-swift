// MARK: - PermissionMode
// From .reference/src/utils/permissions/PermissionMode.ts

public enum PermissionMode: String, Codable, Sendable {
    case `default`
    case plan
    case auto
    case bypassPermissions = "bypassPermissions"
}

// MARK: - ToolPermissionContext
// Mirrors .reference/src/Tool.ts ToolPermissionContext

public struct ToolPermissionContext: Sendable {
    public var mode: PermissionMode
    public var isBypassPermissionsModeAvailable: Bool
    public var isAutoModeAvailable: Bool
    public var shouldAvoidPermissionPrompts: Bool

    public init(
        mode: PermissionMode = .default,
        isBypassPermissionsModeAvailable: Bool = false,
        isAutoModeAvailable: Bool = false,
        shouldAvoidPermissionPrompts: Bool = false
    ) {
        self.mode = mode
        self.isBypassPermissionsModeAvailable = isBypassPermissionsModeAvailable
        self.isAutoModeAvailable = isAutoModeAvailable
        self.shouldAvoidPermissionPrompts = shouldAvoidPermissionPrompts
    }

    public static func empty() -> ToolPermissionContext {
        ToolPermissionContext()
    }
}

// MARK: - AppState
// Ported from .reference/src/state/AppStateStore.ts AppState type.
// This is the core reactive state carried through the entire session.
// React-specific fields (Provider, context) are dropped; data fields are kept.
//
// TODO: extend with reference fields:
//   - tasks: [String: TaskState] (requires TaskState port in Task 12)
//   - mcp: MCPState (requires MCP port in Task 17)
//   - plugins: PluginsState (requires plugins port in Task 16)
//   - fileHistory: FileHistoryState (requires file history port in Task 9)
//   - attribution: AttributionState (requires attribution port)
//   - speculation: SpeculationState (requires speculation port)
//   - inbox, workerSandboxPermissions, teamContext, etc.

public struct AppState: Sendable {
    // MARK: Core session config
    public var verbose: Bool
    /// Main loop model alias/name (nil = use default)
    public var mainLoopModel: String?
    public var mainLoopModelForSession: String?

    // MARK: UI state
    public var statusLineText: String?
    public var expandedView: ExpandedView
    public var isBriefOnly: Bool
    public var selectedIPAgentIndex: Int
    public var coordinatorTaskIndex: Int
    public var viewSelectionMode: ViewSelectionMode

    // MARK: Permissions
    public var toolPermissionContext: ToolPermissionContext

    // MARK: Agent
    /// Agent name from --agent CLI flag or settings
    public var agent: String?
    public var kairosEnabled: Bool

    // MARK: Remote
    public var remoteSessionUrl: String?
    public var remoteConnectionStatus: RemoteConnectionStatus
    public var remoteBackgroundTaskCount: Int

    // MARK: Thinking
    public var thinkingEnabled: Bool?
    public var promptSuggestionEnabled: Bool

    // MARK: Auth
    public var authVersion: Int

    // MARK: Fast mode
    public var fastMode: Bool

    // MARK: Overlays
    public var activeOverlays: Set<String>

    public enum ExpandedView: String, Sendable {
        case none, tasks, teammates
    }

    public enum ViewSelectionMode: String, Sendable {
        case none = "none"
        case selectingAgent = "selecting-agent"
        case viewingAgent = "viewing-agent"
    }

    public enum RemoteConnectionStatus: String, Sendable {
        case connecting, connected, reconnecting, disconnected
    }

    public init(
        verbose: Bool = false,
        mainLoopModel: String? = nil,
        mainLoopModelForSession: String? = nil,
        statusLineText: String? = nil,
        expandedView: ExpandedView = .none,
        isBriefOnly: Bool = false,
        selectedIPAgentIndex: Int = -1,
        coordinatorTaskIndex: Int = -1,
        viewSelectionMode: ViewSelectionMode = .none,
        toolPermissionContext: ToolPermissionContext = .empty(),
        agent: String? = nil,
        kairosEnabled: Bool = false,
        remoteSessionUrl: String? = nil,
        remoteConnectionStatus: RemoteConnectionStatus = .connecting,
        remoteBackgroundTaskCount: Int = 0,
        thinkingEnabled: Bool? = nil,
        promptSuggestionEnabled: Bool = false,
        authVersion: Int = 0,
        fastMode: Bool = false,
        activeOverlays: Set<String> = []
    ) {
        self.verbose = verbose
        self.mainLoopModel = mainLoopModel
        self.mainLoopModelForSession = mainLoopModelForSession
        self.statusLineText = statusLineText
        self.expandedView = expandedView
        self.isBriefOnly = isBriefOnly
        self.selectedIPAgentIndex = selectedIPAgentIndex
        self.coordinatorTaskIndex = coordinatorTaskIndex
        self.viewSelectionMode = viewSelectionMode
        self.toolPermissionContext = toolPermissionContext
        self.agent = agent
        self.kairosEnabled = kairosEnabled
        self.remoteSessionUrl = remoteSessionUrl
        self.remoteConnectionStatus = remoteConnectionStatus
        self.remoteBackgroundTaskCount = remoteBackgroundTaskCount
        self.thinkingEnabled = thinkingEnabled
        self.promptSuggestionEnabled = promptSuggestionEnabled
        self.authVersion = authVersion
        self.fastMode = fastMode
        self.activeOverlays = activeOverlays
    }

    public static func defaultState() -> AppState {
        AppState()
    }
}
