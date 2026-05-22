// MARK: - FeatureFlag

/// All known feature flags. Mirrors the feature('FLAG_NAME') calls in the
/// TypeScript reference source. Values are kept in sync with build.ts / bun-bundle.ts shim.
public enum FeatureFlag: String, CaseIterable, Sendable {
    case voiceMode = "VOICE_MODE"
    case coordinatorMode = "COORDINATOR_MODE"
    case tokenBudget = "TOKEN_BUDGET"
    case teamMemory = "TEAMMEM"
    case agentTriggers = "AGENT_TRIGGERS"
    case messageActions = "MESSAGE_ACTIONS"
    case hookPrompts = "HOOK_PROMPTS"
    case awaySummary = "AWAY_SUMMARY"
    case backgroundSessions = "BG_SESSIONS"
    case buddy = "BUDDY"
    case dumpSystemPrompt = "DUMP_SYSTEM_PROMPT"
    case coworkerTypeTelemetry = "COWORKER_TYPE_TELEMETRY"
    case ultraplan = "ULTRAPLAN"
    case bridgeMode = "BRIDGE_MODE"
    case chicagoMCP = "CHICAGO_MCP"
    case transcriptClassifier = "TRANSCRIPT_CLASSIFIER"
    case kairos = "KAIROS"
    case kairosBrief = "KAIROS_BRIEF"
    case proactive = "PROACTIVE"
    case workflowScripts = "WORKFLOW_SCRIPTS"
    case webBrowserTool = "WEB_BROWSER_TOOL"
    case terminalPanel = "TERMINAL_PANEL"
    case experimentalSkillSearch = "EXPERIMENTAL_SKILL_SEARCH"
    case historySnip = "HISTORY_SNIP"
    case cachedMicrocompact = "CACHED_MICROCOMPACT"
    case ablationBaseline = "ABLATION_BASELINE"
    case overflowTestTool = "OVERFLOW_TEST_TOOL"
}

// MARK: - FeatureFlags

/// Static feature flag lookup table. Mirrors the enabled/disabled split in
/// the TypeScript bun-bundle.ts shim and src/entrypoints/cli.tsx feature setup.
public struct FeatureFlags: Sendable {
    public static let current: [FeatureFlag: Bool] = [
        // Enabled in external builds
        .voiceMode: true,
        .coordinatorMode: true,
        .tokenBudget: true,
        .teamMemory: true,
        .agentTriggers: true,
        .messageActions: true,
        .hookPrompts: true,
        .awaySummary: true,
        .backgroundSessions: true,
        .buddy: true,
        .dumpSystemPrompt: true,
        .coworkerTypeTelemetry: true,
        // Disabled — unreleased / internal / infra-dependent
        .ultraplan: false,
        .bridgeMode: false,
        .chicagoMCP: false,
        .transcriptClassifier: false,
        .kairos: false,
        .kairosBrief: false,
        .proactive: false,
        .workflowScripts: false,
        .webBrowserTool: false,
        .terminalPanel: false,
        .experimentalSkillSearch: false,
        .historySnip: false,
        .cachedMicrocompact: false,
        .ablationBaseline: false,
        .overflowTestTool: false,
    ]

    public static func isEnabled(_ flag: FeatureFlag) -> Bool {
        current[flag] ?? false
    }
}
