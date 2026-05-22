/// ToolRegistry — central registry of all built-in tools.
///
/// Mirrors the logic in .reference/src/tools.ts (getAllBaseTools / getTools).
///
/// Key filtering rules (ported from reference):
/// - Glob + Grep excluded when embedded search tools are available.
/// - PowerShell included only on Windows (never on macOS/Linux).
/// - TestingPermissionTool only in test environment.
/// - ToolSearchTool only when CLAUDE_CODE_OPTIMISTIC_TOOL_SEARCH is set.
/// - MCP resource tools always included.
/// - Feature-flagged / ant-only tools stubbed but not registered by default.

import Foundation
import SwiftCodeCore

// MARK: - ToolRegistry

public final class ToolRegistry: Sendable {

    // MARK: - Singleton

    public static let shared = ToolRegistry()

    // MARK: - All registered handlers (name → handler)

    private let allHandlers: [String: any ToolHandler]

    private init() {
        var h: [String: any ToolHandler] = [:]

        // ── Fully implemented ──────────────────────────────────────────────
        h[BashTool().name]         = BashTool()
        h[FileReadTool().name]     = FileReadTool()
        h[FileWriteTool().name]    = FileWriteTool()
        h[FileEditTool().name]     = FileEditTool()
        h[GlobTool().name]         = GlobTool()
        h[GrepTool().name]         = GrepTool()
        h[TodoWriteTool().name]    = TodoWriteTool()

        // ── Stubs ──────────────────────────────────────────────────────────
        h[AgentToolImpl().name]               = AgentToolImpl()
        h[AskUserQuestionToolImpl().name]     = AskUserQuestionToolImpl()
        h[BriefToolImpl().name]               = BriefToolImpl()
        h[ConfigToolImpl().name]              = ConfigToolImpl()
        h[EnterPlanModeToolImpl().name]       = EnterPlanModeToolImpl()
        h[EnterWorktreeToolImpl().name]       = EnterWorktreeToolImpl()
        h[ExitPlanModeToolImpl().name]        = ExitPlanModeToolImpl()
        h[ExitWorktreeToolImpl().name]        = ExitWorktreeToolImpl()
        h[LSPToolImpl().name]                 = LSPToolImpl()
        h[ListMcpResourcesToolImpl().name]    = ListMcpResourcesToolImpl()
        h[MCPToolImpl().name]                 = MCPToolImpl()
        h[McpAuthToolImpl().name]             = McpAuthToolImpl()
        h[NotebookEditToolImpl().name]        = NotebookEditToolImpl()
        h[PowerShellToolImpl().name]          = PowerShellToolImpl()
        h[REPLToolImpl().name]                = REPLToolImpl()
        h[ReadMcpResourceToolImpl().name]     = ReadMcpResourceToolImpl()
        h[RemoteTriggerToolImpl().name]       = RemoteTriggerToolImpl()
        h[ScheduleCronToolImpl().name]        = ScheduleCronToolImpl()
        h[SendMessageToolImpl().name]         = SendMessageToolImpl()
        h[SkillToolImpl().name]               = SkillToolImpl()
        h[SleepToolImpl().name]               = SleepToolImpl()
        h[SuggestBackgroundPRToolImpl().name] = SuggestBackgroundPRToolImpl()
        h[SyntheticOutputToolImpl().name]     = SyntheticOutputToolImpl()
        h[TaskCreateToolImpl().name]          = TaskCreateToolImpl()
        h[TaskGetToolImpl().name]             = TaskGetToolImpl()
        h[TaskListToolImpl().name]            = TaskListToolImpl()
        h[TaskOutputToolImpl().name]          = TaskOutputToolImpl()
        h[TaskStopToolImpl().name]            = TaskStopToolImpl()
        h[TaskUpdateToolImpl().name]          = TaskUpdateToolImpl()
        h[TeamCreateToolImpl().name]          = TeamCreateToolImpl()
        h[TeamDeleteToolImpl().name]          = TeamDeleteToolImpl()
        h[ToolSearchToolImpl().name]          = ToolSearchToolImpl()
        h[TungstenToolImpl().name]            = TungstenToolImpl()
        h[VerifyPlanExecutionToolImpl().name] = VerifyPlanExecutionToolImpl()
        h[WebFetchToolImpl().name]            = WebFetchToolImpl()
        h[WebSearchToolImpl().name]           = WebSearchToolImpl()
        h[WorkflowToolImpl().name]            = WorkflowToolImpl()

        allHandlers = h
    }

    // MARK: - Lookup

    public func handler(for name: String) -> (any ToolHandler)? {
        allHandlers[name]
    }

    // MARK: - Default preset (mirrors getAllBaseTools filtering)

    /// Returns tool names for the default preset, applying environment-based filtering.
    ///
    /// Logic mirrors .reference/src/tools.ts `getAllBaseTools()`:
    /// - Glob/Grep excluded when embedded search tools active.
    /// - PowerShell excluded on non-Windows (always on macOS).
    /// - TestingPermissionTool excluded outside test env.
    /// - ToolSearchTool excluded unless optimistic tool search enabled.
    public func defaultPresetNames() -> [String] {
        var names: [String] = [
            "Agent",
            "TaskOutput",
            "Bash",
            "ExitPlanMode",
            "Read",
            "Edit",
            "Write",
            "NotebookEdit",
            "WebFetch",
            "TodoWrite",
            "WebSearch",
            "TaskStop",
            "AskUserQuestion",
            "Skill",
            "EnterPlanMode",
            "Brief",
            "SendMessage",
            "ListMcpResources",
            "ReadMcpResource",
        ]

        // Glob + Grep: include unless embedded search tools are available.
        if !hasEmbeddedSearchTools() {
            names.append("Glob")
            names.append("Grep")
        }

        // ToolSearchTool: include when optimistic check passes.
        if isToolSearchEnabledOptimistic() {
            names.append("ToolSearch")
        }

        return names
    }

    // MARK: - Handlers for a name list

    /// Returns the tool handlers corresponding to the given name list.
    /// Unknown names are silently skipped.
    public func handlers(for names: [String]) -> [any ToolHandler] {
        names.compactMap { allHandlers[$0] }
    }

    /// All registered handler names (for tooling / docs).
    public var allNames: [String] { Array(allHandlers.keys).sorted() }
}

// MARK: - Environment checks (mirrors reference)

/// True when ant-embedded bfs/ugrep are bundled in the binary.
/// Always false in this build — we never ship the embedded tools.
private func hasEmbeddedSearchTools() -> Bool { false }

/// True when CLAUDE_CODE_OPTIMISTIC_TOOL_SEARCH is truthy.
private func isToolSearchEnabledOptimistic() -> Bool {
    let env = ProcessInfo.processInfo.environment
    guard let val = env["CLAUDE_CODE_OPTIMISTIC_TOOL_SEARCH"] else { return false }
    return val == "1" || val.lowercased() == "true"
}
