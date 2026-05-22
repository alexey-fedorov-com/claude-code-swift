# Tool Contract Parity Table

Status as of Task 13 (Swift rewrite).

| # | Tool Name | Reference Source Path | Swift Source Path | Status |
|---|-----------|----------------------|-------------------|--------|
| 1 | Bash | src/tools/BashTool/BashTool.tsx | Sources/SwiftCodeTools/BashTool/BashTool.swift | FULL |
| 2 | Read | src/tools/FileReadTool/FileReadTool.ts | Sources/SwiftCodeTools/FileReadTool/FileReadTool.swift | FULL |
| 3 | Write | src/tools/FileWriteTool/ | Sources/SwiftCodeTools/FileWriteTool/FileWriteTool.swift | FULL |
| 4 | Edit | src/tools/FileEditTool/FileEditTool.ts | Sources/SwiftCodeTools/FileEditTool/FileEditTool.swift | FULL |
| 5 | Glob | src/tools/GlobTool/GlobTool.ts | Sources/SwiftCodeTools/GlobTool/GlobTool.swift | FULL |
| 6 | Grep | src/tools/GrepTool/GrepTool.ts | Sources/SwiftCodeTools/GrepTool/GrepTool.swift | FULL |
| 7 | TodoWrite | src/tools/TodoWriteTool/TodoWriteTool.ts | Sources/SwiftCodeTools/TodoWriteTool/TodoWriteTool.swift | FULL |
| 8 | Agent | src/tools/AgentTool/AgentTool.ts | Sources/SwiftCodeTools/AgentTool/AgentTool.swift | STUB (Task 17) |
| 9 | AskUserQuestion | src/tools/AskUserQuestionTool/ | Sources/SwiftCodeTools/AskUserQuestionTool/AskUserQuestionTool.swift | STUB (Task 15) |
| 10 | Brief | src/tools/BriefTool/BriefTool.ts | Sources/SwiftCodeTools/BriefTool/BriefTool.swift | STUB (Task 16) |
| 11 | Config | src/tools/ConfigTool/ConfigTool.ts | Sources/SwiftCodeTools/ConfigTool/ConfigTool.swift | STUB (Task 7/ant-only) |
| 12 | EnterPlanMode | src/tools/EnterPlanModeTool/ | Sources/SwiftCodeTools/EnterPlanModeTool/EnterPlanModeTool.swift | STUB (Task 15) |
| 13 | ExitPlanMode | src/tools/ExitPlanModeTool/ExitPlanModeV2Tool.js | Sources/SwiftCodeTools/ExitPlanModeTool/ExitPlanModeTool.swift | STUB (Task 15) |
| 14 | EnterWorktree | src/tools/EnterWorktreeTool/ | Sources/SwiftCodeTools/EnterWorktreeTool/EnterWorktreeTool.swift | STUB (Task 17) |
| 15 | ExitWorktree | src/tools/ExitWorktreeTool/ | Sources/SwiftCodeTools/ExitWorktreeTool/ExitWorktreeTool.swift | STUB (Task 17) |
| 16 | LSP | src/tools/LSPTool/LSPTool.ts | Sources/SwiftCodeTools/LSPTool/LSPTool.swift | STUB (Task 17) |
| 17 | ListMcpResources | src/tools/ListMcpResourcesTool/ | Sources/SwiftCodeTools/ListMcpResourcesTool/ListMcpResourcesTool.swift | STUB (Task 17) |
| 18 | MCP | (dynamic, via mcpClient) | Sources/SwiftCodeTools/MCPTool/MCPTool.swift | STUB (Task 17) |
| 19 | McpAuth | src/tools/McpAuthTool/ | Sources/SwiftCodeTools/McpAuthTool/McpAuthTool.swift | STUB (Task 17) |
| 20 | NotebookEdit | src/tools/NotebookEditTool/ | Sources/SwiftCodeTools/NotebookEditTool/NotebookEditTool.swift | STUB (Task 16) |
| 21 | PowerShell | src/tools/PowerShellTool/ | Sources/SwiftCodeTools/PowerShellTool/PowerShellTool.swift | STUB (Task 17, Windows-only) |
| 22 | REPL | src/tools/REPLTool/REPLTool.ts | Sources/SwiftCodeTools/REPLTool/REPLTool.swift | STUB (Task 17, ant-only) |
| 23 | ReadMcpResource | src/tools/ReadMcpResourceTool/ | Sources/SwiftCodeTools/ReadMcpResourceTool/ReadMcpResourceTool.swift | STUB (Task 17) |
| 24 | RemoteTrigger | src/tools/RemoteTriggerTool/ | Sources/SwiftCodeTools/RemoteTriggerTool/RemoteTriggerTool.swift | STUB (Task 17, feature-gated) |
| 25 | ScheduleCron | src/tools/ScheduleCronTool/ | Sources/SwiftCodeTools/ScheduleCronTool/ScheduleCronTool.swift | STUB (Task 17) |
| 26 | SendMessage | src/tools/SendMessageTool/ | Sources/SwiftCodeTools/SendMessageTool/SendMessageTool.swift | STUB (Task 17) |
| 27 | Skill | src/tools/SkillTool/ | Sources/SwiftCodeTools/SkillTool/SkillTool.swift | STUB (Task 16) |
| 28 | Sleep | src/tools/SleepTool/ | Sources/SwiftCodeTools/SleepTool/SleepTool.swift | STUB (Task 17, KAIROS-gated) |
| 29 | SuggestBackgroundPR | src/tools/SuggestBackgroundPRTool/ | Sources/SwiftCodeTools/SuggestBackgroundPRTool/SuggestBackgroundPRTool.swift | STUB (Task 17, ant-only) |
| 30 | SyntheticOutput | (inline constant SYNTHETIC_OUTPUT_TOOL_NAME) | Sources/SwiftCodeTools/SyntheticOutputTool/SyntheticOutputTool.swift | STUB (Task 15) |
| 31 | TaskCreate | src/tools/TaskCreateTool/ | Sources/SwiftCodeTools/TaskCreateTool/TaskCreateTool.swift | STUB (Task 17, todo-v2) |
| 32 | TaskGet | src/tools/TaskGetTool/ | Sources/SwiftCodeTools/TaskGetTool/TaskGetTool.swift | STUB (Task 17, todo-v2) |
| 33 | TaskList | src/tools/TaskListTool/ | Sources/SwiftCodeTools/TaskListTool/TaskListTool.swift | STUB (Task 17, todo-v2) |
| 34 | TaskOutput | src/tools/TaskOutputTool/ | Sources/SwiftCodeTools/TaskOutputTool/TaskOutputTool.swift | STUB (Task 17) |
| 35 | TaskStop | src/tools/TaskStopTool/ | Sources/SwiftCodeTools/TaskStopTool/TaskStopTool.swift | STUB (Task 17) |
| 36 | TaskUpdate | src/tools/TaskUpdateTool/ | Sources/SwiftCodeTools/TaskUpdateTool/TaskUpdateTool.swift | STUB (Task 17, todo-v2) |
| 37 | TeamCreate | src/tools/TeamCreateTool/ | Sources/SwiftCodeTools/TeamCreateTool/TeamCreateTool.swift | STUB (Task 17, swarms) |
| 38 | TeamDelete | src/tools/TeamDeleteTool/ | Sources/SwiftCodeTools/TeamDeleteTool/TeamDeleteTool.swift | STUB (Task 17, swarms) |
| 39 | ToolSearch | src/tools/ToolSearchTool/ | Sources/SwiftCodeTools/ToolSearchTool/ToolSearchTool.swift | STUB (Task 17) |
| 40 | Tungsten | src/tools/TungstenTool/ | Sources/SwiftCodeTools/TungstenTool/TungstenTool.swift | STUB (Task 17, ant-only) |
| 41 | VerifyPlanExecution | src/tools/VerifyPlanExecutionTool/ | Sources/SwiftCodeTools/VerifyPlanExecutionTool/VerifyPlanExecutionTool.swift | STUB (Task 17, env-gated) |
| 42 | WebFetch | src/tools/WebFetchTool/ | Sources/SwiftCodeTools/WebFetchTool/WebFetchTool.swift | STUB (Task 17) |
| 43 | WebSearch | src/tools/WebSearchTool/ | Sources/SwiftCodeTools/WebSearchTool/WebSearchTool.swift | STUB (Task 17) |
| 44 | Workflow | src/tools/WorkflowTool/ | Sources/SwiftCodeTools/WorkflowTool/WorkflowTool.swift | STUB (Task 16, WORKFLOW_SCRIPTS-gated) |

## Summary

- **7 fully implemented**: Bash, Read, Write, Edit, Glob, Grep, TodoWrite
- **37 stubs**: All other tools — register in the registry, throw `ToolError.notImplemented` on execute
- **Total registered**: 44 tools

## Shared Infrastructure

| File | Purpose |
|------|---------|
| Sources/SwiftCodeTools/ToolDefinition.swift | JSON schema types (ToolDefinition, ToolInputSchema, PropertySchema) |
| Sources/SwiftCodeTools/ToolResult.swift | ToolError, ToolOutput, ToolHandler protocol, JSONValue helpers |
| Sources/SwiftCodeTools/ReadFileState.swift | Actor tracking which files have been read (needed by FileEditTool) |
| Sources/SwiftCodeTools/ToolRegistry.swift | Central registry + default preset logic |

## Notes

- `FileEditTool` enforces read-before-edit via `ReadFileState.shared`.
- `GrepTool` prefers `rg` (ripgrep) when available in PATH; falls back to `NSRegularExpression`.
- `GlobTool` converts glob patterns to `NSRegularExpression` via `globToRegex()`.
- `TodoWriteTool` stores todos in `TodoStore` (process-global actor), keyed by `sessionId`.
- `ToolRegistry.defaultPresetNames()` mirrors `getAllBaseTools()` filtering from `tools.ts`.
