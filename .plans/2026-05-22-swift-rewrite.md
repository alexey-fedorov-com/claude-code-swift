# Swift Code Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completely replace the current Bun/TypeScript Claude Code reconstruction with a Swift Package Manager project named Swift Code whose `swiftcode` CLI, terminal UX, feature gates, command behavior, tool behavior, persistence formats, and service integrations match the current codebase 1:1 except for the intentional product and executable rename, while preserving the entire original tree under `.reference`.

**Architecture:** Move the current repository contents into `.reference` and treat that tree as read-only behavioral source material. Build a new modular Swift CLI at the repository root with golden-master parity tests that execute `.reference` for observable behavior and Swift unit/integration tests for every ported subsystem. Keep every current enabled feature enabled, every current disabled or stubbed feature disabled or stubbed, and every user-visible string/flag/output contract matched unless the reference behavior is nondeterministic.

**Tech Stack:** Swift 6.3.2, Swift Package Manager, XCTest, Swift Argument Parser 1.7.1, SwiftNIO 2.98.0, AsyncHTTPClient 1.21.2, SwiftLog 1.12.0, Swift Crypto 4.5.0, Foundation, POSIX process/terminal APIs.

---

## Scope And Non-Negotiables

This is a full rewrite, not a bridge layer. The implementation must delete the Bun/TypeScript runtime from the active root and preserve it only under `.reference`.

The rewrite must match the current project exactly except for the intentional product and executable rename:

- Product name is `Swift Code`.
- Top-level executable name is `swiftcode`.
- Package version remains `2.1.88` unless the reference version changes before execution.
- Default invocation launches the interactive REPL.
- `-p/--print` remains pipe-friendly non-interactive mode.
- Existing CLI flags, hidden flags, subcommands, aliases, slash commands, tool schemas, settings schema, transcript format, config paths, command descriptions, help text, permission prompts, hook semantics, plugin behavior, MCP behavior, terminal rendering, and feature-gate behavior are parity requirements.
- Current disabled feature flags stay disabled in Swift: `ULTRAPLAN`, `BRIDGE_MODE`, `CHICAGO_MCP`, `TRANSCRIPT_CLASSIFIER`, `KAIROS`, `KAIROS_BRIEF`, `PROACTIVE`, `WORKFLOW_SCRIPTS`, `WEB_BROWSER_TOOL`, `TERMINAL_PANEL`, `EXPERIMENTAL_SKILL_SEARCH`, `HISTORY_SNIP`, `CACHED_MICROCOMPACT`, `ABLATION_BASELINE`, `OVERFLOW_TEST_TOOL`.
- Current enabled feature flags stay enabled in Swift: `VOICE_MODE`, `COORDINATOR_MODE`, `TOKEN_BUDGET`, `TEAMMEM`, `AGENT_TRIGGERS`, `MESSAGE_ACTIONS`, `HOOK_PROMPTS`, `AWAY_SUMMARY`, `BG_SESSIONS`, `BUDDY`, `DUMP_SYSTEM_PROMPT`, `COWORKER_TYPE_TELEMETRY`.
- Stubbed files remain behaviorally stubbed. Do not complete Anthropic-internal, missing, native-only, or infrastructure-only features beyond the reference behavior.
- The original code under `.reference` is source material and must not be edited except generated build outputs inside `.reference/dist` and dependency caches inside `.reference/node_modules`.

The plan is intentionally one umbrella plan because the user requested one complete rewrite plan. Implementation should still be split into the tasks below and committed after each task.

## Dependency Pins

Dependency versions were checked on 2026-05-22 before writing this plan:

```text
Swift Argument Parser 1.7.1  https://swiftpackageregistry.com/apple/swift-argument-parser
SwiftNIO 2.98.0              https://swiftpackageregistry.com/apple/swift-nio
AsyncHTTPClient 1.21.2       https://swiftpackageregistry.com/swift-server/async-http-client
SwiftLog 1.12.0              https://swiftpackageregistry.com/apple/swift-log
Swift Crypto 4.5.0           https://swiftpackageregistry.com/apple/swift-crypto
```

The implementation may update these pins only if the parity suite stays green and `Package.swift` records the new versions explicitly.

## Current Reference Inventory

Observed on 2026-05-22 in `/Users/alexey/Projects/claude-code-swift`:

- `git ls-files | wc -l`: `2433`
- `find src -type f | wc -l`: `1934`
- `find stubs -type f | wc -l`: `486`
- Plan file: `.plans/2026-05-22-swift-rewrite.md`, excluded from the reference move
- Existing test files: none with real test suites; only `src/ink/hit-test.ts`, `src/services/PromptSuggestion/speculation.ts`, and `src/utils/shell/specPrefix.ts` matched `*test*` or `*spec*` by filename.

Top-level current files and directories to preserve under `.reference`:

```text
.gitignore
CLAUDE.md
README.md
biome.json
build.ts
bun.lock
docs/
package.json
scripts/
shims/
src/
stubs/
tsconfig.json
```

Major source domains:

```text
src/main.tsx                         Commander CLI and startup orchestration
src/entrypoints/cli.tsx              fast-path CLI bootstrap
src/commands.ts                      slash command registry
src/tools.ts                         agent tool registry
src/QueryEngine.ts                   headless/SDK query lifecycle
src/query.ts                         streaming agent loop
src/services/api/claude.ts           Anthropic API streaming and cost accounting
src/screens/REPL.tsx                 interactive REPL
src/ink/                             custom terminal renderer
src/components/                      terminal UI components
src/tools/                           built-in agent tools
src/commands/                        slash commands and top-level command helpers
src/utils/settings/                  settings schema, loading, migration
src/utils/permissions/               permission modes, rules, classifiers
src/utils/hooks/                     hook execution and config
src/utils/plugins/                   plugin marketplace/loading/runtime
src/services/mcp/                    MCP clients, transports, resources, auth
src/services/lsp/                    language server client/manager
src/bridge/, src/remote/, src/server/ remote/bridge/direct-connect surfaces
src/keybindings/, src/vim/           input editing and vim mode
src/native-ts/                       Yoga layout, color diff, file index ports
stubs/                               extracted package stubs and bundled assets
```

## Coverage Strategy

The rewrite uses two independent coverage gates:

- File coverage: `Tests/Golden/reference-files.txt` lists every preserved `.reference` file. `docs/rewrite/source-map.tsv` must contain one row for every file. The checker fails on the first unmapped batch.
- Behavior coverage: golden tests compare Swift CLI stdout, stderr, and exit codes against `.reference/dist/cli.js`; module tests compare structured behavior such as schemas, prompt sections, tool output, terminal snapshots, settings rewrites, and API request construction.

Domain-level wording such as "port tools" is not enough to close a task. Each reference file must be classified as `rewrite`, `reference-only`, `asset`, `generated`, `config`, or `stub`, and every `rewrite` or `stub` row must name a Swift path.

## New File Structure

Create this root-level Swift package after moving the current tree into `.reference`:

```text
Package.swift
README.md
.plans/
  2026-05-22-swift-rewrite.md
docs/
  parity/
    cli-contract.md
    command-contract.md
    tool-contract.md
    settings-contract.md
    ui-contract.md
  rewrite/
    source-map.tsv
scripts/
  capture-reference-golden.sh
  check-reference-coverage.swift
  compare-cli-output.swift
  run-parity.sh
Sources/
  SwiftCode/main.swift
  SwiftCodeCLI/
  SwiftCodeCore/
  SwiftCodeAPI/
  SwiftCodeAgent/
  SwiftCodeTerminalUI/
  SwiftCodeTools/
  SwiftCodeCommands/
  SwiftCodeSettings/
  SwiftCodePermissions/
  SwiftCodeHooks/
  SwiftCodePlugins/
  SwiftCodeMCP/
  SwiftCodeLSP/
  SwiftCodeRemote/
  SwiftCodeVim/
  SwiftCodeNative/
Tests/
  Golden/
  SwiftCodeCLITests/
  SwiftCodeCoreTests/
  SwiftCodeAPITests/
  SwiftCodeAgentTests/
  SwiftCodeTerminalUITests/
  SwiftCodeToolsTests/
  SwiftCodeCommandsTests/
  SwiftCodeSettingsTests/
  SwiftCodePermissionsTests/
  SwiftCodeHooksTests/
  SwiftCodePluginsTests/
  SwiftCodeMCPTests/
  SwiftCodeLSPTests/
  SwiftCodeRemoteTests/
  SwiftCodeVimTests/
  SwiftCodeNativeTests/
```

Target responsibilities:

- `SwiftCode`: executable target only; imports `SwiftCodeCLI` and runs the root command.
- `SwiftCodeCLI`: argument parsing, top-level subcommands, startup sequencing, help/completion output, print/interactive selection.
- `SwiftCodeCore`: feature flags, app state, message types, config home paths, environment helpers, JSON helpers, costs, sessions, migrations, telemetry event types.
- `SwiftCodeAPI`: Anthropic/Bedrock/Vertex/Foundry request construction, streaming parser, retry/fallback behavior, OAuth profile calls, usage accounting, prompt caching headers.
- `SwiftCodeAgent`: query loop, `QueryEngine`, process-user-input flow, compaction, tool orchestration, prompts, system/user context.
- `SwiftCodeTerminalUI`: custom terminal renderer, Yoga port, terminal I/O, alternate screen, event dispatch, components.
- `SwiftCodeTools`: every built-in tool from `src/tools/`, including prompt text, schemas, permissions, UI renderers, and tool result rendering.
- `SwiftCodeCommands`: every slash command from `src/commands.ts` plus dynamic skills/plugin/workflow command loading.
- `SwiftCodeSettings`: settings schemas, config files, managed settings, MDM, remote managed settings, migrations.
- `SwiftCodePermissions`: permission modes, rule parsing, classifier stubs, shell validation, plan/accept/bypass behaviors.
- `SwiftCodeHooks`: hook schemas, config loading, pre/post/session/notification hook execution, hook output truncation to disk.
- `SwiftCodePlugins`: built-in plugins, marketplace management, plugin installation, trust warnings, plugin PATH/bin injection, plugin commands/skills/hooks/agents.
- `SwiftCodeMCP`: MCP JSON parsing, stdio/SSE/HTTP transports, resource/tool/prompt listing, OAuth/XAA, permissions, config policy filtering.
- `SwiftCodeLSP`: JSON-RPC client, LSP server lifecycle, diagnostics, LSP tool formatting.
- `SwiftCodeRemote`: bridge, direct connect, SDK URL, background sessions, remote sessions, SSH/open/server surfaces.
- `SwiftCodeVim`: vim motions, operators, transitions, text objects, keybinding integration.
- `SwiftCodeNative`: process spawning, shell quoting, file operations, keychain/secure storage, terminal capabilities, OS notifications, Git/GitHub helpers.

## Swift Type Contracts

Port these contracts first and use them across all modules:

```swift
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

public struct FeatureFlags: Sendable {
    public static let current: [FeatureFlag: Bool] = [
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
        .overflowTestTool: false
    ]

    public static func isEnabled(_ flag: FeatureFlag) -> Bool {
        current[flag] ?? false
    }
}

public enum PermissionMode: String, Codable, CaseIterable, Sendable {
    case acceptEdits
    case bypassPermissions
    case `default`
    case dontAsk
    case plan
    case auto
    case bubble
}

public enum ExternalPermissionMode: String, Codable, CaseIterable, Sendable {
    case acceptEdits
    case bypassPermissions
    case `default`
    case dontAsk
    case plan
}

public enum PermissionBehavior: String, Codable, Sendable {
    case allow
    case deny
    case ask
}

public struct PermissionRuleValue: Codable, Equatable, Sendable {
    public var toolName: String
    public var ruleContent: String?
}
```

## Command And Tool Coverage Lists

Every command listed here must exist in Swift with matching name, aliases, enablement, hidden status, descriptions, argument hints, local/prompt/local-JSX behavior, non-interactive support, and source.

Slash command directories:

```text
add-dir agents agents-platform ant-trace assistant autofix-pr backfill-sessions branch break-cache bridge btw buddy bughunter chrome clear color compact config context copy cost ctx_viz debug-tool-call desktop diff doctor effort env exit export extra-usage fast feedback files good-claude heapdump help hooks ide install-github-app install-slack-app issue keybindings login logout mcp memory mobile mock-limits model oauth-refresh onboarding output-style passes perf-issue permissions plan plugin pr_comments privacy-settings rate-limit-options release-notes reload-plugins remote-env remote-setup rename reset-limits resume review rewind sandbox-toggle session share skills stats status stickers summary tag tasks teleport terminalSetup theme thinkback thinkback-play upgrade usage vim voice
```

Registry-only command files:

```text
src/commands/advisor.ts
src/commands/brief.ts
src/commands/bridge-kick.ts
src/commands/commit.ts
src/commands/commit-push-pr.ts
src/commands/createMovedToPluginCommand.ts
src/commands/install.tsx
src/commands/init.ts
src/commands/init-verifiers.ts
src/commands/insights.ts
src/commands/review.ts
src/commands/security-review.ts
src/commands/statusline.tsx
src/commands/ultraplan.tsx
src/commands/version.ts
```

Tool directories:

```text
AgentTool AskUserQuestionTool BashTool BriefTool ConfigTool EnterPlanModeTool EnterWorktreeTool ExitPlanModeTool ExitWorktreeTool FileEditTool FileReadTool FileWriteTool GlobTool GrepTool LSPTool ListMcpResourcesTool MCPTool McpAuthTool NotebookEditTool PowerShellTool REPLTool ReadMcpResourceTool RemoteTriggerTool ScheduleCronTool SendMessageTool SkillTool SleepTool SuggestBackgroundPRTool SyntheticOutputTool TaskCreateTool TaskGetTool TaskListTool TaskOutputTool TaskStopTool TaskUpdateTool TeamCreateTool TeamDeleteTool TodoWriteTool ToolSearchTool TungstenTool VerifyPlanExecutionTool WebFetchTool WebSearchTool WorkflowTool shared testing
```

## Requirement Coverage Matrix

| Requirement | Plan Tasks |
| --- | --- |
| Move all current files into `.reference` | Task 1 |
| Keep active root as Swift, not Bun/TypeScript | Tasks 1, 2, 19, 20 |
| Preserve original codebase as reference material | Tasks 1, 3 |
| Rewrite CLI flags, subcommands, help, completion | Tasks 4, 6, 20 |
| Rewrite slash commands | Tasks 4, 14, 20 |
| Rewrite tools | Tasks 8, 9, 13, 20 |
| Rewrite interactive terminal UX | Tasks 10, 15, 20 |
| Rewrite print/SDK/stream-json behavior | Tasks 11, 12, 15, 20 |
| Rewrite settings/config/migrations | Task 7 |
| Rewrite permissions and shell safety | Task 8 |
| Rewrite Anthropic API/auth/model/cost logic | Task 11 |
| Rewrite MCP, LSP, remote, background sessions | Task 17 |
| Rewrite hooks, skills, plugins, bundled assets | Task 16 |
| Rewrite keybindings, vim, voice, memory, telemetry | Task 18 |
| Keep current feature gates and stubs exactly | Tasks 5, 13, 14, 17, 18, 20 |
| Prove every original file was addressed | Tasks 3, 20 |
| Prove user-visible parity | Tasks 4, 10, 13, 14, 15, 20 |

## Task 1: Preserve The Existing Codebase Under `.reference`

**Files:**
- Move: every current root file and directory listed in "Current Reference Inventory" into `.reference/`
- Keep: `.plans/2026-05-22-swift-rewrite.md` in the active root during the move

- [ ] **Step 1: Confirm the worktree state before moving files**

Run:

```bash
git status --short --untracked-files=all
```

Expected:

```text
?? .plans/2026-05-22-swift-rewrite.md
```

If additional paths appear, write them into `docs/rewrite/source-map.tsv` after the scaffold task and preserve them under `.reference` during Step 2.

- [ ] **Step 2: Move the current tree into `.reference`**

Do not move `.git`, `.reference`, `.plans`, or any file created after this step begins.

Run:

```bash
mkdir -p .reference
for path in .gitignore CLAUDE.md README.md biome.json build.ts bun.lock docs package.json scripts shims src stubs tsconfig.json; do
  if [ -e "$path" ]; then
    mv "$path" .reference/
  fi
done
```

Expected:

```text
.reference/.gitignore exists
.reference/src/main.tsx exists
.reference/stubs exists
root src directory does not exist
root package.json does not exist
```

- [ ] **Step 3: Verify the active plan path remains outside `.reference`**

Run:

```bash
test -f .plans/2026-05-22-swift-rewrite.md
test ! -e .reference/.plans/2026-05-22-swift-rewrite.md
```

Expected:

```text
.plans/2026-05-22-swift-rewrite.md remains in the active root
```

- [ ] **Step 4: Commit the reference preservation**

Run:

```bash
git add .reference .plans/2026-05-22-swift-rewrite.md
git commit -m "chore: preserve TypeScript reference implementation"
```

Expected: commit succeeds with the original tracked files now under `.reference/`.

## Task 2: Scaffold The Swift Package

**Files:**
- Create: `Package.swift`
- Create: `README.md`
- Create: `Sources/SwiftCode/main.swift`
- Create: `Sources/SwiftCodeCLI/SwiftCodeCommand.swift`
- Create: all module directories listed in "New File Structure"
- Test: `Tests/SwiftCodeCLITests/VersionCommandTests.swift`

- [ ] **Step 1: Create `Package.swift`**

Use this manifest:

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "SwiftCode",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "swiftcode", targets: ["SwiftCode"]),
        .library(name: "SwiftCodeCLI", targets: ["SwiftCodeCLI"]),
        .library(name: "SwiftCodeCore", targets: ["SwiftCodeCore"]),
        .library(name: "SwiftCodeAPI", targets: ["SwiftCodeAPI"]),
        .library(name: "SwiftCodeAgent", targets: ["SwiftCodeAgent"]),
        .library(name: "SwiftCodeTerminalUI", targets: ["SwiftCodeTerminalUI"]),
        .library(name: "SwiftCodeTools", targets: ["SwiftCodeTools"]),
        .library(name: "SwiftCodeCommands", targets: ["SwiftCodeCommands"]),
        .library(name: "SwiftCodeSettings", targets: ["SwiftCodeSettings"]),
        .library(name: "SwiftCodePermissions", targets: ["SwiftCodePermissions"]),
        .library(name: "SwiftCodeHooks", targets: ["SwiftCodeHooks"]),
        .library(name: "SwiftCodePlugins", targets: ["SwiftCodePlugins"]),
        .library(name: "SwiftCodeMCP", targets: ["SwiftCodeMCP"]),
        .library(name: "SwiftCodeLSP", targets: ["SwiftCodeLSP"]),
        .library(name: "SwiftCodeRemote", targets: ["SwiftCodeRemote"]),
        .library(name: "SwiftCodeVim", targets: ["SwiftCodeVim"]),
        .library(name: "SwiftCodeNative", targets: ["SwiftCodeNative"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.98.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.2"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.5.0")
    ],
    targets: [
        .executableTarget(
            name: "SwiftCode",
            dependencies: ["SwiftCodeCLI"]
        ),
        .target(
            name: "SwiftCodeCLI",
            dependencies: [
                "SwiftCodeCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(name: "SwiftCodeCore", dependencies: [.product(name: "Logging", package: "swift-log")]),
        .target(name: "SwiftCodeAPI", dependencies: ["SwiftCodeCore", .product(name: "AsyncHTTPClient", package: "async-http-client")]),
        .target(name: "SwiftCodeAgent", dependencies: ["SwiftCodeCore", "SwiftCodeAPI"]),
        .target(name: "SwiftCodeTerminalUI", dependencies: ["SwiftCodeCore", .product(name: "NIOCore", package: "swift-nio")]),
        .target(name: "SwiftCodeTools", dependencies: ["SwiftCodeCore", "SwiftCodeAgent", "SwiftCodeTerminalUI"]),
        .target(name: "SwiftCodeCommands", dependencies: ["SwiftCodeCore", "SwiftCodeTools", "SwiftCodeTerminalUI"]),
        .target(name: "SwiftCodeSettings", dependencies: ["SwiftCodeCore"]),
        .target(name: "SwiftCodePermissions", dependencies: ["SwiftCodeCore", "SwiftCodeSettings"]),
        .target(name: "SwiftCodeHooks", dependencies: ["SwiftCodeCore", "SwiftCodeSettings"]),
        .target(name: "SwiftCodePlugins", dependencies: ["SwiftCodeCore", "SwiftCodeSettings", "SwiftCodeHooks"]),
        .target(name: "SwiftCodeMCP", dependencies: ["SwiftCodeCore", "SwiftCodeAPI", "SwiftCodePermissions", .product(name: "NIOCore", package: "swift-nio")]),
        .target(name: "SwiftCodeLSP", dependencies: ["SwiftCodeCore", .product(name: "NIOCore", package: "swift-nio")]),
        .target(name: "SwiftCodeRemote", dependencies: ["SwiftCodeCore", "SwiftCodeAPI", "SwiftCodeAgent", .product(name: "NIOCore", package: "swift-nio")]),
        .target(name: "SwiftCodeVim", dependencies: ["SwiftCodeCore"]),
        .target(name: "SwiftCodeNative", dependencies: ["SwiftCodeCore", .product(name: "Crypto", package: "swift-crypto")]),
        .testTarget(name: "SwiftCodeCLITests", dependencies: ["SwiftCodeCLI"]),
        .testTarget(name: "SwiftCodeCoreTests", dependencies: ["SwiftCodeCore"]),
        .testTarget(name: "SwiftCodeAPITests", dependencies: ["SwiftCodeAPI"]),
        .testTarget(name: "SwiftCodeAgentTests", dependencies: ["SwiftCodeAgent"]),
        .testTarget(name: "SwiftCodeTerminalUITests", dependencies: ["SwiftCodeTerminalUI"]),
        .testTarget(name: "SwiftCodeToolsTests", dependencies: ["SwiftCodeTools"]),
        .testTarget(name: "SwiftCodeCommandsTests", dependencies: ["SwiftCodeCommands"]),
        .testTarget(name: "SwiftCodeSettingsTests", dependencies: ["SwiftCodeSettings"]),
        .testTarget(name: "SwiftCodePermissionsTests", dependencies: ["SwiftCodePermissions"]),
        .testTarget(name: "SwiftCodeHooksTests", dependencies: ["SwiftCodeHooks"]),
        .testTarget(name: "SwiftCodePluginsTests", dependencies: ["SwiftCodePlugins"]),
        .testTarget(name: "SwiftCodeMCPTests", dependencies: ["SwiftCodeMCP"]),
        .testTarget(name: "SwiftCodeLSPTests", dependencies: ["SwiftCodeLSP"]),
        .testTarget(name: "SwiftCodeRemoteTests", dependencies: ["SwiftCodeRemote"]),
        .testTarget(name: "SwiftCodeVimTests", dependencies: ["SwiftCodeVim"]),
        .testTarget(name: "SwiftCodeNativeTests", dependencies: ["SwiftCodeNative"])
    ]
)
```

- [ ] **Step 2: Create the executable entrypoint**

Create `Sources/SwiftCode/main.swift`:

```swift
import SwiftCodeCLI

await SwiftCodeCommand.main()
```

- [ ] **Step 3: Create the initial root command**

Create `Sources/SwiftCodeCLI/SwiftCodeCommand.swift`:

```swift
import ArgumentParser

public struct SwiftCodeCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "swiftcode",
        abstract: "Swift Code - starts an interactive session by default, use -p/--print for non-interactive output",
        version: "2.1.88"
    )

    @Argument(help: "Your prompt")
    public var prompt: String?

    @Flag(name: [.short, .customLong("print")], help: "Print response and exit (useful for pipes). Note: The workspace trust dialog is skipped when Swift Code is run with the -p mode. Only use this flag in directories you trust.")
    public var printMode = false

    public init() {}

    public mutating func run() async throws {
        if printMode {
            FileHandle.standardOutput.write(Data("Swift rewrite scaffold\n".utf8))
        } else {
            FileHandle.standardOutput.write(Data("Swift rewrite scaffold\n".utf8))
        }
    }
}
```

- [ ] **Step 4: Write the first failing CLI version test**

Create `Tests/SwiftCodeCLITests/VersionCommandTests.swift`:

```swift
import XCTest

final class VersionCommandTests: XCTestCase {
    func testVersionTextMatchesReferenceVersion() throws {
        let package = ProcessInfo.processInfo.environment["PACKAGE_BINARY"]
            ?? "\(FileManager.default.currentDirectoryPath)/.build/debug/swiftcode"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: package)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(output, "2.1.88 (Swift Code)\n")
    }
}
```

- [ ] **Step 5: Run the scaffold build**

Run:

```bash
swift build
```

Expected: build succeeds and `.build/debug/swiftcode` exists.

- [ ] **Step 6: Run the version test with the built binary**

Run:

```bash
PACKAGE_BINARY="$PWD/.build/debug/swiftcode" swift test --filter VersionCommandTests/testVersionTextMatchesReferenceVersion
```

Expected: test fails until `--version` is wired through `ArgumentParser` exactly.

- [ ] **Step 7: Commit the SwiftPM scaffold**

Run:

```bash
git add Package.swift README.md Sources Tests
git commit -m "chore: scaffold Swift package"
```

Expected: commit succeeds.

## Task 3: Build The Reference Inventory And Coverage Gate

**Files:**
- Create: `docs/rewrite/source-map.tsv`
- Create: `scripts/check-reference-coverage.swift`
- Create: `Tests/Golden/reference-files.txt`
- Test: `scripts/check-reference-coverage.swift`

- [ ] **Step 1: Capture every preserved reference file**

Run:

```bash
mkdir -p Tests/Golden docs/rewrite scripts
find .reference \
  -path .reference/.git -prune -o \
  -path .reference/node_modules -prune -o \
  -path .reference/dist -prune -o \
  -type f -print | sed 's#^\./##' | sort > Tests/Golden/reference-files.txt
```

Expected:

```text
Tests/Golden/reference-files.txt contains .reference/src/main.tsx
Tests/Golden/reference-files.txt contains .reference/stubs/downloads/claude-agent-sdk/sdk.mjs
Tests/Golden/reference-files.txt contains .reference/CLAUDE.md
```

- [ ] **Step 2: Create the initial source mapping file**

Create `docs/rewrite/source-map.tsv` with this header and initial rows:

```text
reference_path	swift_target	status	notes
.reference/.gitignore	root	config	preserve ignore behavior in new .gitignore
.reference/CLAUDE.md	docs	reference-only	preserved repo guidance
.reference/README.md	README.md	rewrite	replace with Swift rewrite README while preserving reference README
.reference/package.json	Package.swift	rewrite	replace Bun package metadata with SwiftPM metadata
.reference/build.ts	Package.swift	rewrite	replace Bun build with SwiftPM build and release scripts
.reference/bun.lock	Package.resolved	rewrite	replace Bun lockfile with SwiftPM resolution
.reference/tsconfig.json	Package.swift	rewrite	replace TypeScript config with Swift compiler settings
.reference/biome.json	.swift-format	rewrite	replace Biome formatting with Swift formatting
.reference/shims/bun-bundle.ts	Sources/SwiftCodeCore/FeatureFlags.swift	rewrite	port feature gate behavior exactly
.reference/shims/bun-bundle.d.ts	Sources/SwiftCodeCore/FeatureFlags.swift	rewrite	port feature gate type surface exactly
.reference/src/main.tsx	Sources/SwiftCodeCLI/SwiftCodeCommand.swift	rewrite	port root CLI parser and startup behavior
.reference/src/entrypoints/cli.tsx	Sources/SwiftCodeCLI/Bootstrap.swift	rewrite	port fast-path startup behavior
.reference/src/commands.ts	Sources/SwiftCodeCommands/CommandRegistry.swift	rewrite	port command registry and filtering
.reference/src/tools.ts	Sources/SwiftCodeTools/ToolRegistry.swift	rewrite	port tool registry and filtering
.reference/src/Tool.ts	Sources/SwiftCodeCore/ToolContracts.swift	rewrite	port tool contract types
.reference/src/QueryEngine.ts	Sources/SwiftCodeAgent/QueryEngine.swift	rewrite	port headless query engine
.reference/src/query.ts	Sources/SwiftCodeAgent/QueryLoop.swift	rewrite	port streaming query loop
.reference/src/screens/REPL.tsx	Sources/SwiftCodeCLI/InteractiveREPL.swift	rewrite	port interactive REPL behavior
```

- [ ] **Step 3: Create the coverage checker**

Create `scripts/check-reference-coverage.swift`:

```swift
#!/usr/bin/env swift
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let referenceList = root.appendingPathComponent("Tests/Golden/reference-files.txt")
let sourceMap = root.appendingPathComponent("docs/rewrite/source-map.tsv")

let referenceText = try String(contentsOf: referenceList, encoding: .utf8)
let mappedText = try String(contentsOf: sourceMap, encoding: .utf8)

let references = Set(referenceText.split(separator: "\n").map(String.init))
let rows = mappedText.split(separator: "\n").dropFirst()
let mapped = Set(rows.compactMap { row -> String? in
    let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    return columns.first
})

let missing = references.subtracting(mapped).sorted()
if !missing.isEmpty {
    FileHandle.standardError.write(Data("Missing source-map rows:\n".utf8))
    for path in missing.prefix(200) {
        FileHandle.standardError.write(Data("\(path)\n".utf8))
    }
    if missing.count > 200 {
        FileHandle.standardError.write(Data("... \(missing.count - 200) more\n".utf8))
    }
    exit(1)
}

print("reference coverage complete: \(references.count) files")
```

- [ ] **Step 4: Run the coverage checker and observe missing rows**

Run:

```bash
swift scripts/check-reference-coverage.swift
```

Expected: failure listing unmapped `.reference/...` files. This failure is required at this point because only the seed rows exist.

- [ ] **Step 5: Populate the full source map**

For every path in `Tests/Golden/reference-files.txt`, add exactly one row to `docs/rewrite/source-map.tsv`.

Status values:

```text
rewrite          Swift implementation required
reference-only   preserved for docs, legal context, bundled package source, or examples
asset            copied as runtime data into Sources or Resources
generated        regenerated by Swift build scripts or SwiftPM
config           replaced by root config with same behavior
stub             Swift stub matching current runtime behavior
```

Expected mapping rules:

```text
.reference/src/**              rewrite or stub
.reference/stubs/downloads/**  asset or reference-only
.reference/stubs/@ant/**       stub or reference-only
.reference/stubs/@anthropic-ai/** asset or reference-only
.reference/docs/**             reference-only except active rewrite plan copy
.reference/scripts/**          rewrite or reference-only
.reference/shims/**            rewrite
```

- [ ] **Step 6: Run the coverage checker until it passes**

Run:

```bash
swift scripts/check-reference-coverage.swift
```

Expected:

```text
reference coverage complete: <file-count> files
```

- [ ] **Step 7: Commit the inventory gate**

Run:

```bash
git add Tests/Golden/reference-files.txt docs/rewrite/source-map.tsv scripts/check-reference-coverage.swift
git commit -m "test: require reference source coverage"
```

Expected: commit succeeds.

## Task 4: Capture Golden CLI Contracts From `.reference`

**Files:**
- Create: `scripts/capture-reference-golden.sh`
- Create: `scripts/compare-cli-output.swift`
- Create: `scripts/run-parity.sh`
- Create: `docs/parity/cli-contract.md`
- Create: `Tests/Golden/cli/*.stdout`
- Create: `Tests/Golden/cli/*.stderr`
- Test: `scripts/run-parity.sh`

- [ ] **Step 1: Build the reference implementation**

Run:

```bash
cd .reference
bun install
bun run build
```

Expected:

```text
Build succeeded: dist/cli.js
```

- [ ] **Step 2: Create the golden capture script**

Create `scripts/capture-reference-golden.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="$ROOT/.reference/dist/cli.js"
OUT="$ROOT/Tests/Golden/cli"
mkdir -p "$OUT"

capture() {
  local name="$1"
  shift
  set +e
  bun "$REF" "$@" >"$OUT/$name.stdout" 2>"$OUT/$name.stderr"
  local code=$?
  set -e
  printf "%s\n" "$code" >"$OUT/$name.exit"
}

capture version --version
capture short_version -v
capture help --help
capture mcp_help mcp --help
capture auth_help auth --help
capture plugin_help plugin --help
capture completion_help completion --help
capture print_empty -p ""
capture dump_system_prompt --dump-system-prompt
```

- [ ] **Step 3: Create the CLI comparison script**

Create `scripts/compare-cli-output.swift`:

```swift
#!/usr/bin/env swift
import Foundation

struct CommandCase {
    let name: String
    let args: [String]
}

let cases: [CommandCase] = [
    .init(name: "version", args: ["--version"]),
    .init(name: "short_version", args: ["-v"]),
    .init(name: "help", args: ["--help"]),
    .init(name: "mcp_help", args: ["mcp", "--help"]),
    .init(name: "auth_help", args: ["auth", "--help"]),
    .init(name: "plugin_help", args: ["plugin", "--help"]),
    .init(name: "completion_help", args: ["completion", "--help"]),
    .init(name: "print_empty", args: ["-p", ""]),
    .init(name: "dump_system_prompt", args: ["--dump-system-prompt"])
]

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let binary = root.appendingPathComponent(".build/debug/swiftcode").path
let golden = root.appendingPathComponent("Tests/Golden/cli")

func run(_ args: [String]) throws -> (Int32, String, String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: binary)
    process.arguments = args
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    return (
        process.terminationStatus,
        String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
        String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    )
}

func normalizeIntentionalRebrand(_ text: String) -> String {
    let productRenamed = text.replacingOccurrences(of: "Claude Code", with: "Swift Code")
    let pattern = #"(?<![A-Za-z0-9_.-])claude(?![A-Za-z0-9_.-])"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(productRenamed.startIndex..<productRenamed.endIndex, in: productRenamed)
    return regex.stringByReplacingMatches(in: productRenamed, range: range, withTemplate: "swiftcode")
}

var failures: [String] = []
for item in cases {
    let expectedExit = try String(contentsOf: golden.appendingPathComponent("\(item.name).exit")).trimmingCharacters(in: .whitespacesAndNewlines)
    let expectedStdout = normalizeIntentionalRebrand(try String(contentsOf: golden.appendingPathComponent("\(item.name).stdout")))
    let expectedStderr = normalizeIntentionalRebrand(try String(contentsOf: golden.appendingPathComponent("\(item.name).stderr")))
    let actual = try run(item.args)
    if "\(actual.0)" != expectedExit { failures.append("\(item.name): exit \(actual.0) != \(expectedExit)") }
    if actual.1 != expectedStdout { failures.append("\(item.name): stdout differs") }
    if actual.2 != expectedStderr { failures.append("\(item.name): stderr differs") }
}

if failures.isEmpty {
    print("CLI parity passed")
} else {
    for failure in failures { FileHandle.standardError.write(Data("\(failure)\n".utf8)) }
    exit(1)
}
```

- [ ] **Step 4: Create the parity runner**

Create `scripts/run-parity.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

swift build
PACKAGE_BINARY="$PWD/.build/debug/swiftcode" swift test
swift scripts/check-reference-coverage.swift
swift scripts/compare-cli-output.swift
```

- [ ] **Step 5: Capture reference output**

Run:

```bash
chmod +x scripts/capture-reference-golden.sh scripts/run-parity.sh
scripts/capture-reference-golden.sh
```

Expected: raw reference output in `Tests/Golden/cli/version.stdout` contains `2.1.88 (Claude Code)`; `scripts/compare-cli-output.swift` normalizes the intentional rebrand to `2.1.88 (Swift Code)` before comparing Swift output.

- [ ] **Step 6: Write the CLI contract document**

Create `docs/parity/cli-contract.md` with:

```markdown
# CLI Parity Contract

The Swift executable is named `swiftcode`.

The root command description, version output, visible help text, hidden flag behavior, subcommand tree, aliases, exit codes, stdout, and stderr must match `.reference/dist/cli.js` after applying the intentional rebrand mapping: `Claude Code` -> `Swift Code` and command-token `claude` -> `swiftcode`.

Golden outputs live in `Tests/Golden/cli`.

Commands covered by mandatory golden tests:

- `swiftcode --version`
- `swiftcode -v`
- `swiftcode --help`
- `swiftcode mcp --help`
- `swiftcode auth --help`
- `swiftcode plugin --help`
- `swiftcode completion --help`
- `swiftcode -p ""`
- `swiftcode --dump-system-prompt`
```

- [ ] **Step 7: Commit golden CLI contracts**

Run:

```bash
git add scripts/capture-reference-golden.sh scripts/compare-cli-output.swift scripts/run-parity.sh docs/parity/cli-contract.md Tests/Golden/cli
git commit -m "test: capture reference CLI contracts"
```

Expected: commit succeeds.

## Task 5: Port Core Types, Feature Flags, Messages, And State

**Files:**
- Create: `Sources/SwiftCodeCore/FeatureFlags.swift`
- Create: `Sources/SwiftCodeCore/Version.swift`
- Create: `Sources/SwiftCodeCore/Messages.swift`
- Create: `Sources/SwiftCodeCore/AppState.swift`
- Create: `Sources/SwiftCodeCore/ToolContracts.swift`
- Create: `Sources/SwiftCodeCore/CommandContracts.swift`
- Create: `Sources/SwiftCodeCore/Environment.swift`
- Test: `Tests/SwiftCodeCoreTests/FeatureFlagsTests.swift`
- Test: `Tests/SwiftCodeCoreTests/MessageCodableTests.swift`

- [ ] **Step 1: Write failing feature flag tests**

Create `Tests/SwiftCodeCoreTests/FeatureFlagsTests.swift`:

```swift
import XCTest
@testable import SwiftCodeCore

final class FeatureFlagsTests: XCTestCase {
    func testEnabledFlagsMatchReferenceBuildTs() {
        XCTAssertTrue(FeatureFlags.isEnabled(.voiceMode))
        XCTAssertTrue(FeatureFlags.isEnabled(.coordinatorMode))
        XCTAssertTrue(FeatureFlags.isEnabled(.tokenBudget))
        XCTAssertTrue(FeatureFlags.isEnabled(.teamMemory))
        XCTAssertTrue(FeatureFlags.isEnabled(.agentTriggers))
        XCTAssertTrue(FeatureFlags.isEnabled(.messageActions))
        XCTAssertTrue(FeatureFlags.isEnabled(.hookPrompts))
        XCTAssertTrue(FeatureFlags.isEnabled(.awaySummary))
        XCTAssertTrue(FeatureFlags.isEnabled(.backgroundSessions))
        XCTAssertTrue(FeatureFlags.isEnabled(.buddy))
        XCTAssertTrue(FeatureFlags.isEnabled(.dumpSystemPrompt))
        XCTAssertTrue(FeatureFlags.isEnabled(.coworkerTypeTelemetry))
    }

    func testDisabledFlagsMatchReferenceBuildTs() {
        XCTAssertFalse(FeatureFlags.isEnabled(.ultraplan))
        XCTAssertFalse(FeatureFlags.isEnabled(.bridgeMode))
        XCTAssertFalse(FeatureFlags.isEnabled(.chicagoMCP))
        XCTAssertFalse(FeatureFlags.isEnabled(.transcriptClassifier))
        XCTAssertFalse(FeatureFlags.isEnabled(.kairos))
        XCTAssertFalse(FeatureFlags.isEnabled(.kairosBrief))
        XCTAssertFalse(FeatureFlags.isEnabled(.proactive))
        XCTAssertFalse(FeatureFlags.isEnabled(.workflowScripts))
        XCTAssertFalse(FeatureFlags.isEnabled(.webBrowserTool))
        XCTAssertFalse(FeatureFlags.isEnabled(.terminalPanel))
        XCTAssertFalse(FeatureFlags.isEnabled(.experimentalSkillSearch))
        XCTAssertFalse(FeatureFlags.isEnabled(.historySnip))
        XCTAssertFalse(FeatureFlags.isEnabled(.cachedMicrocompact))
        XCTAssertFalse(FeatureFlags.isEnabled(.ablationBaseline))
        XCTAssertFalse(FeatureFlags.isEnabled(.overflowTestTool))
    }
}
```

- [ ] **Step 2: Implement `FeatureFlags.swift` and `Version.swift`**

Use the contracts from the "Swift Type Contracts" section and create:

```swift
public enum SwiftCodeVersion {
    public static let value = "2.1.88"
    public static let display = "2.1.88 (Swift Code)"
}
```

- [ ] **Step 3: Port message and state contracts**

Port these reference files into Swift Codable/Sendable models:

```text
.reference/src/types/message.ts -> Sources/SwiftCodeCore/Messages.swift
.reference/src/Tool.ts -> Sources/SwiftCodeCore/ToolContracts.swift
.reference/src/types/command.ts -> Sources/SwiftCodeCore/CommandContracts.swift
.reference/src/state/AppState.tsx -> Sources/SwiftCodeCore/AppState.swift
.reference/src/state/AppStateStore.ts -> Sources/SwiftCodeCore/AppStateStore.swift
.reference/src/bootstrap/state.ts -> Sources/SwiftCodeCore/BootstrapState.swift
```

Required Swift model families:

```text
Message
UserMessage
AssistantMessage
SystemMessage
ProgressMessage
ToolUseContext
ToolPermissionContext
Tool
Command
LocalCommandResult
AppState
SessionId
AgentId
ThinkingConfig
QuerySource
```

- [ ] **Step 4: Write Codable round-trip tests**

Create `Tests/SwiftCodeCoreTests/MessageCodableTests.swift`:

```swift
import XCTest
@testable import SwiftCodeCore

final class MessageCodableTests: XCTestCase {
    func testUserTextMessageRoundTrips() throws {
        let message = Message.user(UserMessage(uuid: "00000000-0000-0000-0000-000000000001", content: .text("hello"), isMeta: false))
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertEqual(decoded, message)
    }

    func testAssistantToolUseMessageRoundTrips() throws {
        let message = Message.assistant(AssistantMessage(
            uuid: "00000000-0000-0000-0000-000000000002",
            content: [.toolUse(id: "toolu_1", name: "Read", input: ["file_path": .string("README.md")])],
            usage: nil,
            stopReason: nil
        ))
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertEqual(decoded, message)
    }
}
```

- [ ] **Step 5: Run core tests**

Run:

```bash
swift test --filter SwiftCodeCoreTests
```

Expected: all core tests pass.

- [ ] **Step 6: Commit core contracts**

Run:

```bash
git add Sources/SwiftCodeCore Tests/SwiftCodeCoreTests
git commit -m "feat: port core contracts and feature flags"
```

Expected: commit succeeds.

## Task 6: Port CLI Bootstrap, Flags, Subcommands, Help, And Completion

**Files:**
- Modify: `Sources/SwiftCodeCLI/SwiftCodeCommand.swift`
- Create: `Sources/SwiftCodeCLI/Bootstrap.swift`
- Create: `Sources/SwiftCodeCLI/RootOptions.swift`
- Create: `Sources/SwiftCodeCLI/MCPSubcommands.swift`
- Create: `Sources/SwiftCodeCLI/AuthSubcommands.swift`
- Create: `Sources/SwiftCodeCLI/PluginSubcommands.swift`
- Create: `Sources/SwiftCodeCLI/CompletionSubcommand.swift`
- Test: `Tests/SwiftCodeCLITests/HelpParityTests.swift`

- [ ] **Step 1: Port root options from `.reference/src/main.tsx`**

Implement every visible and hidden root option listed in `rg "\.option\(|\.addOption" .reference/src/main.tsx`.

Required root options include:

```text
[prompt]
-h, --help
-d, --debug [filter]
-d2e, --debug-to-stderr
--debug-file <path>
--verbose
-p, --print
--bare
--init
--init-only
--maintenance
--output-format <format>
--json-schema <schema>
--include-hook-events
--include-partial-messages
--input-format <format>
--mcp-debug
--dangerously-skip-permissions
--allow-dangerously-skip-permissions
--thinking <mode>
--max-thinking-tokens <tokens>
--max-turns <turns>
--max-budget-usd <amount>
--replay-user-messages
--enable-auth-status
--allowedTools, --allowed-tools <tools...>
--tools <tools...>
--disallowedTools, --disallowed-tools <tools...>
--mcp-config <configs...>
--permission-prompt-tool <tool>
--system-prompt <prompt>
--system-prompt-file <file>
--append-system-prompt <prompt>
--append-system-prompt-file <file>
--permission-mode <mode>
-c, --continue
-r, --resume [value]
--fork-session
--prefill <text>
--deep-link-origin
--deep-link-repo <slug>
--deep-link-last-fetch <ms>
--from-pr [value]
--no-session-persistence
--resume-session-at <message id>
--rewind-files <user-message-id>
--model <model>
--effort <level>
--agent <agent>
--betas <betas...>
--fallback-model <model>
--workload <tag>
--settings <file-or-json>
--add-dir <directories...>
--ide
--strict-mcp-config
--session-id <uuid>
-n, --name <name>
--agents <json>
--setting-sources <sources>
--plugin-dir <path>
--disable-slash-commands
--chrome
--no-chrome
--file <specs...>
-w, --worktree [name]
--tmux
--agent-id <id>
--agent-name <name>
--team-name <name>
--agent-color <color>
--plan-mode-required
--parent-session-id <id>
--teammate-mode <mode>
--agent-type <type>
--sdk-url <url>
--teleport [session]
--remote [description]
--hard-fail
```

- [ ] **Step 2: Port top-level subcommands from `.reference/src/main.tsx`**

Implement root subcommands and aliases:

```text
mcp
server
ssh
open
auth
plugin, plugins
setup-token
agents
auto-mode
remote-control
assistant
doctor
update, upgrade
install
task
completion
```

Feature-gated or ant-only commands must appear or hide exactly as the reference does under the same environment.

- [ ] **Step 3: Run CLI parity**

Run:

```bash
swift build
swift scripts/compare-cli-output.swift
```

Expected: help/version cases match `Tests/Golden/cli`.

- [ ] **Step 4: Commit CLI parity**

Run:

```bash
git add Sources/SwiftCodeCLI Tests/SwiftCodeCLITests
git commit -m "feat: port CLI parser and help contracts"
```

Expected: commit succeeds.

## Task 7: Port Settings, Config, Environment, And Migrations

**Files:**
- Create: `Sources/SwiftCodeSettings/SettingsSchema.swift`
- Create: `Sources/SwiftCodeSettings/SettingsLoader.swift`
- Create: `Sources/SwiftCodeSettings/GlobalConfig.swift`
- Create: `Sources/SwiftCodeSettings/ProjectConfig.swift`
- Create: `Sources/SwiftCodeSettings/Migrations.swift`
- Create: `Sources/SwiftCodeCore/ConfigPaths.swift`
- Test: `Tests/SwiftCodeSettingsTests/SettingsSchemaTests.swift`
- Test: `Tests/SwiftCodeSettingsTests/MigrationTests.swift`

- [ ] **Step 1: Port settings source files**

Port:

```text
.reference/src/utils/config.ts
.reference/src/utils/settings/types.ts
.reference/src/utils/settings/settings.ts
.reference/src/utils/settings/validation.ts
.reference/src/utils/settings/constants.ts
.reference/src/utils/settings/managedPath.ts
.reference/src/utils/settings/schemaOutput.ts
.reference/src/utils/settings/mdm/rawRead.ts
.reference/src/utils/settings/mdm/settings.ts
.reference/src/migrations/*.ts
```

Required behavior:

```text
Config home resolves like reference getClaudeConfigHomeDir.
Global config supports legacy fields and preserves unknown JSON fields.
Project config keys match reference ProjectConfig.
Settings sources load in user, project, local, policy, flag order.
Invalid settings are reported and preserved on disk.
Migrations run once and mark their guard fields exactly as reference code.
```

- [ ] **Step 2: Write settings schema tests**

Test these exact cases:

```text
permissions.defaultMode accepts default, acceptEdits, bypassPermissions, dontAsk, plan
permissions.defaultMode rejects auto when TRANSCRIPT_CLASSIFIER is false
cleanupPeriodDays: 0 is rejected with the no-session-persistence guidance
disableSkillShellExecution is decoded as a Boolean setting
unknown fields are preserved when settings are rewritten
```

- [ ] **Step 3: Run settings tests**

Run:

```bash
swift test --filter SwiftCodeSettingsTests
```

Expected: all settings tests pass.

- [ ] **Step 4: Commit settings**

Run:

```bash
git add Sources/SwiftCodeSettings Sources/SwiftCodeCore/ConfigPaths.swift Tests/SwiftCodeSettingsTests
git commit -m "feat: port settings and migrations"
```

Expected: commit succeeds.

## Task 8: Port Permissions And Shell Safety

**Files:**
- Create: `Sources/SwiftCodePermissions/PermissionMode.swift`
- Create: `Sources/SwiftCodePermissions/PermissionRuleParser.swift`
- Create: `Sources/SwiftCodePermissions/PermissionUpdates.swift`
- Create: `Sources/SwiftCodePermissions/ShellRuleMatching.swift`
- Create: `Sources/SwiftCodePermissions/BashSafety.swift`
- Create: `Sources/SwiftCodePermissions/PowerShellSafety.swift`
- Test: `Tests/SwiftCodePermissionsTests/PermissionRuleParserTests.swift`
- Test: `Tests/SwiftCodePermissionsTests/ShellSafetyTests.swift`

- [ ] **Step 1: Port permission files**

Port:

```text
.reference/src/types/permissions.ts
.reference/src/utils/permissions/*.ts
.reference/src/tools/BashTool/bashPermissions.ts
.reference/src/tools/BashTool/readOnlyValidation.ts
.reference/src/tools/BashTool/destructiveCommandWarning.ts
.reference/src/tools/PowerShellTool/powershellPermissions.ts
.reference/src/tools/PowerShellTool/readOnlyValidation.ts
.reference/src/tools/PowerShellTool/destructiveCommandWarning.ts
```

Required behavior:

```text
Permission modes expose the same display title, short title, symbol, color key, and external mapping.
Permission rules parse tool names and optional rule content with the same wildcard semantics.
Dangerous filesystem locations include .husky.
DNS cache commands are not auto-allowed.
Bypass and auto-mode killswitch checks mirror reference behavior.
Classifier prompt files remain unavailable because TRANSCRIPT_CLASSIFIER is false.
```

- [ ] **Step 2: Run permission tests**

Run:

```bash
swift test --filter SwiftCodePermissionsTests
```

Expected: all permission tests pass.

- [ ] **Step 3: Commit permissions**

Run:

```bash
git add Sources/SwiftCodePermissions Tests/SwiftCodePermissionsTests
git commit -m "feat: port permissions and shell safety"
```

Expected: commit succeeds.

## Task 9: Port Native Process, Filesystem, Git, Terminal, And Secure Storage

**Files:**
- Create: `Sources/SwiftCodeNative/ProcessRunner.swift`
- Create: `Sources/SwiftCodeNative/FileSystem.swift`
- Create: `Sources/SwiftCodeNative/ShellQuoting.swift`
- Create: `Sources/SwiftCodeNative/GitClient.swift`
- Create: `Sources/SwiftCodeNative/SecureStorage.swift`
- Create: `Sources/SwiftCodeNative/TerminalCapabilities.swift`
- Create: `Sources/SwiftCodeNative/Notifications.swift`
- Test: `Tests/SwiftCodeNativeTests/ProcessRunnerTests.swift`
- Test: `Tests/SwiftCodeNativeTests/ShellQuotingTests.swift`
- Test: `Tests/SwiftCodeNativeTests/GitClientTests.swift`

- [ ] **Step 1: Port native helpers**

Port behavior from:

```text
.reference/src/utils/Shell.ts
.reference/src/utils/process.ts
.reference/src/utils/fsOperations.ts
.reference/src/utils/git.ts
.reference/src/utils/github/*.ts
.reference/src/utils/secureStorage/*.ts
.reference/src/ink/terminal.ts
.reference/src/ink/terminal-querier.ts
.reference/src/services/notifier.ts
```

Required behavior:

```text
Process execution streams stdout/stderr and supports abort.
Shell quoting matches reference shell-quote behavior for Bash and PowerShell.
Git root, branch, worktree count, and dirty state match reference command outputs.
macOS keychain paths match the reference secure storage keys.
Terminal capability detection covers hyperlinks, alternate screen, focus events, bracketed paste, cursor visibility, and notification escape sequences.
```

- [ ] **Step 2: Run native tests**

Run:

```bash
swift test --filter SwiftCodeNativeTests
```

Expected: all native tests pass.

- [ ] **Step 3: Commit native layer**

Run:

```bash
git add Sources/SwiftCodeNative Tests/SwiftCodeNativeTests
git commit -m "feat: port native process and terminal helpers"
```

Expected: commit succeeds.

## Task 10: Port Terminal Renderer, Yoga Layout, Events, And Components

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/Yoga/*.swift`
- Create: `Sources/SwiftCodeTerminalUI/Renderer/*.swift`
- Create: `Sources/SwiftCodeTerminalUI/Events/*.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/*.swift`
- Create: `docs/parity/ui-contract.md`
- Test: `Tests/SwiftCodeTerminalUITests/YogaLayoutTests.swift`
- Test: `Tests/SwiftCodeTerminalUITests/RendererSnapshotTests.swift`
- Test: `Tests/SwiftCodeTerminalUITests/InputEventTests.swift`

- [ ] **Step 1: Port custom Ink files**

Port:

```text
.reference/src/ink/layout/*.ts
.reference/src/native-ts/yoga-layout/*.ts
.reference/src/ink/styles.ts
.reference/src/ink/dom.ts
.reference/src/ink/reconciler.ts
.reference/src/ink/renderer.ts
.reference/src/ink/render-node-to-output.ts
.reference/src/ink/output.ts
.reference/src/ink/events/*.ts
.reference/src/ink/hooks/*.ts
.reference/src/ink/components/*.tsx
.reference/src/ink/termio/*.ts
.reference/src/components/**/*.tsx
```

Required behavior:

```text
Flexbox dimensions, wrapping, borders, margins, padding, gap, overflow, and text wrapping match reference snapshots.
ANSI color, SGR, OSC, CSI, DEC parsing and rendering match reference.
Keyboard, paste, focus, mouse, click, and terminal resize events match reference.
All user-visible component text and spacing match reference snapshots.
```

- [ ] **Step 2: Create UI contract document**

Create `docs/parity/ui-contract.md` describing required snapshots:

```markdown
# Terminal UI Parity Contract

The Swift renderer must match the reference custom Ink output for:

- Welcome screen
- Prompt input footer
- Help dialog
- Permission request dialog
- MCP approval dialog
- Tool use rows
- File edit diff
- Markdown rendering
- Spinner frames
- Vim prompt mode indicator
- Status line
- Resume picker
- Plugin picker
- Settings dialogs

Snapshots must compare normalized ANSI output. Dynamic timestamps, UUIDs, terminal width, and API request IDs are masked before comparison.
```

- [ ] **Step 3: Run terminal UI tests**

Run:

```bash
swift test --filter SwiftCodeTerminalUITests
```

Expected: all renderer and input tests pass.

- [ ] **Step 4: Commit terminal UI**

Run:

```bash
git add Sources/SwiftCodeTerminalUI Tests/SwiftCodeTerminalUITests docs/parity/ui-contract.md
git commit -m "feat: port terminal renderer and UI components"
```

Expected: commit succeeds.

## Task 11: Port API, Auth, Streaming, Cost, Retry, And Model Logic

**Files:**
- Create: `Sources/SwiftCodeAPI/AnthropicClient.swift`
- Create: `Sources/SwiftCodeAPI/StreamingParser.swift`
- Create: `Sources/SwiftCodeAPI/Auth.swift`
- Create: `Sources/SwiftCodeAPI/ModelRegistry.swift`
- Create: `Sources/SwiftCodeAPI/CostTracker.swift`
- Create: `Sources/SwiftCodeAPI/RetryPolicy.swift`
- Test: `Tests/SwiftCodeAPITests/StreamingParserTests.swift`
- Test: `Tests/SwiftCodeAPITests/RequestConstructionTests.swift`
- Test: `Tests/SwiftCodeAPITests/CostTrackerTests.swift`

- [ ] **Step 1: Port API files**

Port:

```text
.reference/src/services/api/*.ts
.reference/src/services/oauth/*.ts
.reference/src/utils/auth.ts
.reference/src/utils/model/**/*.ts
.reference/src/utils/context.ts
.reference/src/utils/tokens.ts
.reference/src/cost-tracker.ts
.reference/src/constants/betas.ts
.reference/src/constants/oauth.ts
.reference/src/constants/product.ts
```

Required behavior:

```text
Anthropic, Bedrock, Vertex, and Foundry provider selection matches reference environment detection.
OAuth login, token refresh, API key helper, and keychain prefetch match reference behavior.
Streaming events normalize to the same internal Message values.
Prompt cache, effort, fast mode, thinking, structured output, tool search, and advisor headers match reference gating.
Usage and cost math match reference model cost tables.
Retry and fallback-model behavior produce the same user-visible errors.
```

- [ ] **Step 2: Run API tests**

Run:

```bash
swift test --filter SwiftCodeAPITests
```

Expected: all API tests pass.

- [ ] **Step 3: Commit API layer**

Run:

```bash
git add Sources/SwiftCodeAPI Tests/SwiftCodeAPITests
git commit -m "feat: port API streaming and auth"
```

Expected: commit succeeds.

## Task 12: Port Agent Query Loop, System Prompts, Context, And Compaction

**Files:**
- Create: `Sources/SwiftCodeAgent/QueryEngine.swift`
- Create: `Sources/SwiftCodeAgent/QueryLoop.swift`
- Create: `Sources/SwiftCodeAgent/SystemPrompt.swift`
- Create: `Sources/SwiftCodeAgent/ContextBuilder.swift`
- Create: `Sources/SwiftCodeAgent/Compaction.swift`
- Create: `Sources/SwiftCodeAgent/ToolOrchestration.swift`
- Test: `Tests/SwiftCodeAgentTests/QueryLoopTests.swift`
- Test: `Tests/SwiftCodeAgentTests/SystemPromptParityTests.swift`
- Test: `Tests/SwiftCodeAgentTests/CompactionTests.swift`

- [ ] **Step 1: Port agent files**

Port:

```text
.reference/src/QueryEngine.ts
.reference/src/query.ts
.reference/src/query/*.ts
.reference/src/constants/prompts.ts
.reference/src/constants/systemPromptSections.ts
.reference/src/context.ts
.reference/src/services/compact/*.ts
.reference/src/services/toolUseSummary/*.ts
.reference/src/utils/messages/**/*.ts
.reference/src/utils/api.ts
.reference/src/utils/queryHelpers.ts
.reference/src/utils/processUserInput/**/*.ts
```

Required behavior:

```text
System prompt static and dynamic boundaries match reference.
Model aliases resolve to the same canonical model IDs.
Tool result pairing and missing tool result recovery match reference.
Auto-compact thresholds, warnings, and circuit breaker messages match reference.
Microcompact, session memory compact, prompt-too-long, max-output-token recovery, and stop hooks match reference.
SDK stream-json events match reference shape and ordering.
```

- [ ] **Step 2: Run agent tests**

Run:

```bash
swift test --filter SwiftCodeAgentTests
```

Expected: all agent tests pass.

- [ ] **Step 3: Commit agent loop**

Run:

```bash
git add Sources/SwiftCodeAgent Tests/SwiftCodeAgentTests
git commit -m "feat: port query loop and prompts"
```

Expected: commit succeeds.

## Task 13: Port Built-In Tools

**Files:**
- Create: `Sources/SwiftCodeTools/ToolRegistry.swift`
- Create: one Swift file or focused folder per tool listed in "Command And Tool Coverage Lists"
- Create: `docs/parity/tool-contract.md`
- Test: `Tests/SwiftCodeToolsTests/*Tests.swift`

- [ ] **Step 1: Port tool registry**

Port `.reference/src/tools.ts` to `Sources/SwiftCodeTools/ToolRegistry.swift`.

Required registry behavior:

```text
Default tool preset returns enabled base tool names.
Embedded search tools remove Glob and Grep exactly as reference does.
PowerShell tool is added only when reference would enable it.
TestingPermissionTool appears only in test environment.
ToolSearchTool appears only when optimistic tool search is enabled.
MCP resource tools are always included.
```

- [ ] **Step 2: Port tool implementations**

Port every file under:

```text
.reference/src/tools/AgentTool
.reference/src/tools/AskUserQuestionTool
.reference/src/tools/BashTool
.reference/src/tools/BriefTool
.reference/src/tools/ConfigTool
.reference/src/tools/EnterPlanModeTool
.reference/src/tools/EnterWorktreeTool
.reference/src/tools/ExitPlanModeTool
.reference/src/tools/ExitWorktreeTool
.reference/src/tools/FileEditTool
.reference/src/tools/FileReadTool
.reference/src/tools/FileWriteTool
.reference/src/tools/GlobTool
.reference/src/tools/GrepTool
.reference/src/tools/LSPTool
.reference/src/tools/ListMcpResourcesTool
.reference/src/tools/MCPTool
.reference/src/tools/McpAuthTool
.reference/src/tools/NotebookEditTool
.reference/src/tools/PowerShellTool
.reference/src/tools/REPLTool
.reference/src/tools/ReadMcpResourceTool
.reference/src/tools/RemoteTriggerTool
.reference/src/tools/ScheduleCronTool
.reference/src/tools/SendMessageTool
.reference/src/tools/SkillTool
.reference/src/tools/SleepTool
.reference/src/tools/SuggestBackgroundPRTool
.reference/src/tools/SyntheticOutputTool
.reference/src/tools/TaskCreateTool
.reference/src/tools/TaskGetTool
.reference/src/tools/TaskListTool
.reference/src/tools/TaskOutputTool
.reference/src/tools/TaskStopTool
.reference/src/tools/TaskUpdateTool
.reference/src/tools/TeamCreateTool
.reference/src/tools/TeamDeleteTool
.reference/src/tools/TodoWriteTool
.reference/src/tools/ToolSearchTool
.reference/src/tools/TungstenTool
.reference/src/tools/VerifyPlanExecutionTool
.reference/src/tools/WebFetchTool
.reference/src/tools/WebSearchTool
.reference/src/tools/WorkflowTool
.reference/src/tools/shared
.reference/src/tools/testing
```

Required behavior:

```text
Tool names, descriptions, prompt text, JSON schemas, validation failures, permission checks, progress events, UI output, truncation, and result message formatting match reference.
Read/Edit/Write preserve file-read state semantics, including Bash-viewed file tracking.
Bash and PowerShell permissions reuse Task 8 shell safety.
WebFetch and WebSearch match reference preapproval, citation, and error behavior.
Agent, team, task, cron, and worktree tools match current enabled feature behavior.
REPL, Tungsten, SuggestBackgroundPR, Workflow, VerifyPlanExecution, and missing feature tools stay stubbed or gated exactly as reference.
```

- [ ] **Step 3: Create tool contract document**

Create `docs/parity/tool-contract.md` listing every tool name, source path, Swift path, schema snapshot path, and golden test path.

- [ ] **Step 4: Run tool tests**

Run:

```bash
swift test --filter SwiftCodeToolsTests
```

Expected: all tool tests pass.

- [ ] **Step 5: Commit tools**

Run:

```bash
git add Sources/SwiftCodeTools Tests/SwiftCodeToolsTests docs/parity/tool-contract.md
git commit -m "feat: port built-in tools"
```

Expected: commit succeeds.

## Task 14: Port Slash Commands And Command Registry

**Files:**
- Create: `Sources/SwiftCodeCommands/CommandRegistry.swift`
- Create: focused Swift files/folders for every command listed in "Command And Tool Coverage Lists"
- Create: `docs/parity/command-contract.md`
- Test: `Tests/SwiftCodeCommandsTests/CommandRegistryTests.swift`
- Test: `Tests/SwiftCodeCommandsTests/CommandParityTests.swift`

- [ ] **Step 1: Port command registry**

Port `.reference/src/commands.ts`.

Required behavior:

```text
Built-in command names and aliases match reference.
Internal-only commands appear only for USER_TYPE=ant and not IS_DEMO.
Feature-gated commands appear only when current feature flags enable them.
Dynamic skill, bundled skill, plugin command, plugin skill, workflow command, and dynamic skill insertion order match reference.
Availability filtering for claude-ai and console users matches reference.
```

- [ ] **Step 2: Port every command implementation**

Port every file under `.reference/src/commands/` and every registry-only command file listed earlier.

Required command groups:

```text
session/control: clear compact context cost exit export resume rewind session status statusline stats usage extra-usage
configuration: config model effort fast theme vim keybindings output-style privacy-settings permissions sandbox-toggle add-dir files memory
auth/account: login logout auth status setup-token passes rate-limit-options reset-limits
tools/integrations: mcp ide hooks plugin reload-plugins skills chrome desktop mobile voice remote-env install-github-app install-slack-app
workflows: agents branch tasks plan thinkback thinkback-play review security-review diff copy tag rename feedback release-notes
internal/stubbed: ant-trace autofix-pr backfill-sessions break-cache bughunter ctx_viz debug-tool-call env good-claude issue mock-limits onboarding perf-issue share summary teleport version agents-platform assistant bridge buddy stickers oauth-refresh
```

- [ ] **Step 3: Run command tests**

Run:

```bash
swift test --filter SwiftCodeCommandsTests
swift scripts/compare-cli-output.swift
```

Expected: all command tests and golden CLI comparisons pass.

- [ ] **Step 4: Commit commands**

Run:

```bash
git add Sources/SwiftCodeCommands Tests/SwiftCodeCommandsTests docs/parity/command-contract.md
git commit -m "feat: port slash commands"
```

Expected: commit succeeds.

## Task 15: Port Interactive REPL And Non-Interactive Print Mode

**Files:**
- Create: `Sources/SwiftCodeCLI/InteractiveREPL.swift`
- Create: `Sources/SwiftCodeCLI/PrintMode.swift`
- Create: `Sources/SwiftCodeCLI/StructuredIO.swift`
- Create: `Sources/SwiftCodeCLI/MessageQueue.swift`
- Test: `Tests/SwiftCodeCLITests/PrintModeParityTests.swift`
- Test: `Tests/SwiftCodeCLITests/StructuredIOTests.swift`
- Test: `Tests/SwiftCodeCLITests/REPLInputTests.swift`

- [ ] **Step 1: Port REPL and print files**

Port:

```text
.reference/src/screens/REPL.tsx
.reference/src/cli/print.ts
.reference/src/cli/structuredIO.ts
.reference/src/cli/remoteIO.ts
.reference/src/replLauncher.tsx
.reference/src/interactiveHelpers.tsx
.reference/src/history.ts
.reference/src/utils/messageQueueManager.ts
.reference/src/components/PromptInput/**/*.tsx
```

Required behavior:

```text
Default launch path renders the same welcome, prompt, hints, notifications, dialogs, and footer.
Print mode supports text, json, stream-json, input stream-json, partial messages, hook events, auth status, replayed user messages, max turns, max budget, structured output schema, session persistence off, and SDK URL.
Command queue, slash command execution, shell mode, paste handling, image/file attachments, prompt history, early input, interruptions, and cancellation match reference.
```

- [ ] **Step 2: Run REPL and print tests**

Run:

```bash
swift test --filter SwiftCodeCLITests
```

Expected: all REPL and print mode tests pass.

- [ ] **Step 3: Commit REPL and print mode**

Run:

```bash
git add Sources/SwiftCodeCLI Tests/SwiftCodeCLITests
git commit -m "feat: port REPL and print mode"
```

Expected: commit succeeds.

## Task 16: Port Hooks, Skills, Plugins, Bundled Assets, And Output Styles

**Files:**
- Create: `Sources/SwiftCodeHooks/*.swift`
- Create: `Sources/SwiftCodePlugins/*.swift`
- Create: `Sources/SwiftCodeCommands/Skills/*.swift`
- Create: `Sources/SwiftCodeCore/Resources/`
- Test: `Tests/SwiftCodeHooksTests/*Tests.swift`
- Test: `Tests/SwiftCodePluginsTests/*Tests.swift`

- [ ] **Step 1: Port hooks**

Port:

```text
.reference/src/schemas/hooks.ts
.reference/src/utils/hooks/*.ts
.reference/src/hooks/**/*.ts
.reference/src/services/hooks if present in source-map
```

Required behavior:

```text
PreToolUse, PostToolUse, Notification, Stop, SubagentStop, PreCompact, SessionStart, SessionEnd, UserPromptSubmit, and Prompt hooks match reference event payloads.
Hook command execution, HTTP hooks, prompt hooks, agent hooks, timeouts, large output truncation to temp files, and defer permission decisions match reference.
```

- [ ] **Step 2: Port skills and bundled skills**

Port:

```text
.reference/src/skills/**/*.ts
.reference/src/skills/bundled/**/*.ts
.reference/src/skills/bundled/**/SKILL.md
```

Required behavior:

```text
Bundled skills load with the same names and content.
Skill directory loading, frontmatter parsing, disableSkillShellExecution, path triggers, dynamic skill discovery, and shell prompt execution behavior match reference.
```

- [ ] **Step 3: Port plugin system**

Port:

```text
.reference/src/plugins/**/*.ts
.reference/src/utils/plugins/**/*.ts
.reference/src/services/plugins/*.ts
.reference/src/commands/plugin/**/*.tsx
.reference/stubs/downloads/official-plugins/**
```

Required behavior:

```text
Marketplace add/list/remove/update, plugin install/uninstall/enable/disable/update/list/validate, trust warning, manifest validation, zip cache, MCPB handling, plugin commands, plugin skills, plugin hooks, plugin agents, output styles, plugin bin PATH injection, managed plugins, and official marketplace startup checks match reference.
```

- [ ] **Step 4: Run hooks and plugins tests**

Run:

```bash
swift test --filter SwiftCodeHooksTests
swift test --filter SwiftCodePluginsTests
```

Expected: all hooks and plugin tests pass.

- [ ] **Step 5: Commit hooks, skills, and plugins**

Run:

```bash
git add Sources/SwiftCodeHooks Sources/SwiftCodePlugins Sources/SwiftCodeCommands/Skills Sources/SwiftCodeCore/Resources Tests/SwiftCodeHooksTests Tests/SwiftCodePluginsTests
git commit -m "feat: port hooks skills and plugins"
```

Expected: commit succeeds.

## Task 17: Port MCP, OAuth/XAA, LSP, Remote, Background Sessions, And Bridge Surfaces

**Files:**
- Create: `Sources/SwiftCodeMCP/*.swift`
- Create: `Sources/SwiftCodeLSP/*.swift`
- Create: `Sources/SwiftCodeRemote/*.swift`
- Test: `Tests/SwiftCodeMCPTests/*Tests.swift`
- Test: `Tests/SwiftCodeLSPTests/*Tests.swift`
- Test: `Tests/SwiftCodeRemoteTests/*Tests.swift`

- [ ] **Step 1: Port MCP**

Port:

```text
.reference/src/services/mcp/**/*.ts
.reference/src/commands/mcp/**/*.ts
.reference/src/components/mcp/**/*.tsx
.reference/src/tools/MCPTool
.reference/src/tools/ListMcpResourcesTool
.reference/src/tools/ReadMcpResourceTool
.reference/src/tools/McpAuthTool
```

Required behavior:

```text
MCP config parsing, stdio/SSE/HTTP transports, tool/resource/prompt discovery, server health checks, OAuth flow, XAA IDP flow, channel allowlist, permissions, elicitation, max result size override, enterprise allow/deny policy, and Claude.ai MCP configs match reference.
```

- [ ] **Step 2: Port LSP**

Port:

```text
.reference/src/services/lsp/**/*.ts
.reference/src/tools/LSPTool
.reference/src/components/LspRecommendation/**
.reference/src/utils/plugins/lsp*.ts
```

Required behavior:

```text
JSON-RPC framing, server startup, diagnostics registry, passive feedback, symbol formatting, LSP recommendation notifications, and plugin-provided LSP integration match reference.
```

- [ ] **Step 3: Port remote and background surfaces**

Port:

```text
.reference/src/bridge/**/*.ts
.reference/src/remote/**/*.ts
.reference/src/server/**/*.ts
.reference/src/cli/bg.ts
.reference/src/cli/transports/**/*.ts
.reference/src/tasks/**/*.ts
.reference/src/coordinator/**/*.ts
```

Required behavior:

```text
Background session ps/logs/attach/kill, --bg/--background, direct-connect server/open/ssh paths, SDK WebSocket URL, remote session manager, bridge-disabled behavior, coordinator mode, teammate tasks, task list watching, remote agent tasks, and disabled bridge feature behavior match reference.
```

- [ ] **Step 4: Run MCP/LSP/remote tests**

Run:

```bash
swift test --filter SwiftCodeMCPTests
swift test --filter SwiftCodeLSPTests
swift test --filter SwiftCodeRemoteTests
```

Expected: all MCP, LSP, and remote tests pass.

- [ ] **Step 5: Commit MCP, LSP, and remote**

Run:

```bash
git add Sources/SwiftCodeMCP Sources/SwiftCodeLSP Sources/SwiftCodeRemote Tests/SwiftCodeMCPTests Tests/SwiftCodeLSPTests Tests/SwiftCodeRemoteTests
git commit -m "feat: port MCP LSP and remote sessions"
```

Expected: commit succeeds.

## Task 18: Port Vim Mode, Keybindings, Suggestions, Voice, Memory, And Telemetry

**Files:**
- Create: `Sources/SwiftCodeVim/*.swift`
- Create: `Sources/SwiftCodeCLI/Keybindings/*.swift`
- Create: `Sources/SwiftCodeAgent/Memory/*.swift`
- Create: `Sources/SwiftCodeCore/Telemetry/*.swift`
- Test: `Tests/SwiftCodeVimTests/*Tests.swift`
- Test: `Tests/SwiftCodeCoreTests/TelemetryTests.swift`

- [ ] **Step 1: Port vim and keybindings**

Port:

```text
.reference/src/vim/*.ts
.reference/src/keybindings/*.ts
.reference/src/components/VimTextInput.tsx
.reference/src/components/PromptInput/inputModes.ts
```

Required behavior:

```text
Vim motions, text objects, operators, transitions, insert/normal mode, keybinding parsing, reserved shortcuts, shortcut display, custom keybindings, and validation warnings match reference.
```

- [ ] **Step 2: Port memory and suggestions**

Port:

```text
.reference/src/memdir/**/*.ts
.reference/src/services/SessionMemory/**/*.ts
.reference/src/services/extractMemories/**/*.ts
.reference/src/services/teamMemorySync/**/*.ts
.reference/src/services/PromptSuggestion/**/*.ts
.reference/src/services/autoDream/**/*.ts
.reference/src/projectOnboardingState.ts
```

Required behavior:

```text
CLAUDE.md discovery, nested memory attachments, @path includes, frontmatter paths, HTML comment stripping, session memory, team memory, extract memories, auto dream, prompt suggestions, and project onboarding state match reference.
```

- [ ] **Step 3: Port voice and telemetry**

Port:

```text
.reference/src/voice/**
.reference/src/services/voice*.ts
.reference/src/services/analytics/**/*.ts
.reference/src/services/diagnosticTracking.ts
.reference/src/services/internalLogging.ts
.reference/src/utils/telemetry/**/*.ts
.reference/src/utils/diagLogs.ts
```

Required behavior:

```text
VOICE_MODE stays enabled.
Voice command and hold-to-talk dictation behavior match reference where required backend services are available.
Telemetry disable environment variables, Datadog/GrowthBook/first-party sinks, diagnostic logs, privacy level, and opt-out behavior match reference.
```

- [ ] **Step 4: Run vim, memory, and telemetry tests**

Run:

```bash
swift test --filter SwiftCodeVimTests
swift test --filter SwiftCodeCoreTests/TelemetryTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit vim, keybindings, memory, voice, and telemetry**

Run:

```bash
git add Sources/SwiftCodeVim Sources/SwiftCodeCLI/Keybindings Sources/SwiftCodeAgent/Memory Sources/SwiftCodeCore/Telemetry Tests/SwiftCodeVimTests Tests/SwiftCodeCoreTests
git commit -m "feat: port input modes memory voice and telemetry"
```

Expected: commit succeeds.

## Task 19: Port Build, Install, Release, Docs, And Distribution Behavior

**Files:**
- Create: `.gitignore`
- Create: `.swift-format`
- Create: `docs/BUILD-LOG.md`
- Create: `scripts/build-release.sh`
- Create: `scripts/install-local.sh`
- Modify: `README.md`
- Test: `scripts/build-release.sh`

- [ ] **Step 1: Replace root ignore and formatting config**

Create `.gitignore`:

```gitignore
.build/
.swiftpm/
.DS_Store
Package.resolved
.reference/node_modules/
.reference/dist/
```

Create `.swift-format`:

```json
{
  "version": 1,
  "lineLength": 140,
  "indentation": {
    "spaces": 4
  }
}
```

- [ ] **Step 2: Create release build script**

Create `scripts/build-release.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
swift build -c release
mkdir -p dist
cp .build/release/swiftcode dist/swiftcode
dist/swiftcode --version
```

Expected output includes:

```text
2.1.88 (Swift Code)
```

- [ ] **Step 3: Create local install script**

Create `scripts/install-local.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/build-release.sh"
mkdir -p "$HOME/.local/bin"
cp "$ROOT/dist/swiftcode" "$HOME/.local/bin/swiftcode"
"$HOME/.local/bin/swiftcode" --version
```

- [ ] **Step 4: Write Swift rewrite README**

Create `README.md` with:

````markdown
# Swift Code

This repository is a Swift rewrite of the preserved TypeScript/Bun reference implementation stored under `.reference`.

Build:

```bash
swift build
```

Run:

```bash
swift run swiftcode
swift run swiftcode -- --version
swift run swiftcode -- -p "hello"
```

Parity:

```bash
scripts/run-parity.sh
```

The active Swift implementation must match `.reference` user-visible behavior 1:1.
````

- [ ] **Step 5: Run release build**

Run:

```bash
chmod +x scripts/build-release.sh scripts/install-local.sh
scripts/build-release.sh
```

Expected: release binary exists at `dist/swiftcode` and prints `2.1.88 (Swift Code)`.

- [ ] **Step 6: Commit build and docs**

Run:

```bash
git add .gitignore .swift-format README.md docs/BUILD-LOG.md scripts/build-release.sh scripts/install-local.sh
git commit -m "chore: add Swift build and install scripts"
```

Expected: commit succeeds.

## Task 20: Final Full-System Parity Verification

**Files:**
- Modify: `docs/rewrite/source-map.tsv`
- Create: `docs/parity/final-report.md`
- Test: all tests and scripts

- [ ] **Step 1: Run the full verification suite**

Run:

```bash
scripts/run-parity.sh
scripts/build-release.sh
```

Expected:

```text
swift build passes
swift test passes
reference coverage complete: <file-count> files
CLI parity passed
dist/swiftcode --version prints 2.1.88 (Swift Code)
```

- [ ] **Step 2: Verify no unmapped reference files remain**

Run:

```bash
swift scripts/check-reference-coverage.swift
```

Expected:

```text
reference coverage complete: <file-count> files
```

- [ ] **Step 3: Verify the active root contains no TypeScript runtime source outside `.reference`**

Run:

```bash
find . -path './.reference' -prune -o \( -name '*.ts' -o -name '*.tsx' -o -name 'package.json' -o -name 'bun.lock' -o -name 'tsconfig.json' \) -print
```

Expected: no output, except Swift rewrite tooling files explicitly recorded in `docs/rewrite/source-map.tsv` with status `config` or `generated`.

- [ ] **Step 4: Write final parity report**

Create `docs/parity/final-report.md`:

```markdown
# Final Swift Rewrite Parity Report

Reference preserved at `.reference`.

Verification commands:

- `swift build`
- `swift test`
- `swift scripts/check-reference-coverage.swift`
- `swift scripts/compare-cli-output.swift`
- `scripts/build-release.sh`

All commands passed in the final verification run.

Coverage:

- Every file from `Tests/Golden/reference-files.txt` has one row in `docs/rewrite/source-map.tsv`.
- Every command from `.reference/src/commands.ts` has a Swift implementation or a Swift gate/stub matching reference behavior.
- Every tool from `.reference/src/tools.ts` has a Swift implementation or a Swift gate/stub matching reference behavior.
- Every enabled feature flag from `.reference/build.ts` is enabled in Swift.
- Every disabled feature flag from `.reference/build.ts` is disabled in Swift.
```

- [ ] **Step 5: Commit final parity report**

Run:

```bash
git add docs/parity/final-report.md docs/rewrite/source-map.tsv
git commit -m "test: document final Swift parity"
```

Expected: commit succeeds.

## Execution Order

Execute tasks in numeric order. Do not start porting commands before core, settings, permissions, native, terminal UI, API, and agent contracts exist. Do not mark a subsystem complete until its tests and source-map rows pass.

Commit after every task. If a task touches a file with user changes, inspect the diff and preserve user work.

## Definition Of Done

The rewrite is complete only when:

- `.reference` contains the original current codebase.
- The active root is a Swift Package Manager project.
- `swift build` passes.
- `swift test` passes.
- `scripts/run-parity.sh` passes.
- `scripts/build-release.sh` creates `dist/swiftcode`.
- `dist/swiftcode --version` prints `2.1.88 (Swift Code)`.
- `swift scripts/check-reference-coverage.swift` passes.
- `find . -path './.reference' -prune -o \( -name '*.ts' -o -name '*.tsx' -o -name 'package.json' -o -name 'bun.lock' -o -name 'tsconfig.json' \) -print` produces no active runtime source files.
- Every command, tool, setting, hook, plugin, MCP surface, UI component, terminal behavior, prompt, API behavior, migration, disabled feature, enabled feature, and stubbed feature in the reference is represented in Swift or documented as reference-only asset/source material.

## Review Log

Draft 1 created on 2026-05-22 after inspecting the current root, package metadata, CLI entrypoints, command registry, tool registry, settings, permissions, UI renderer, query loop, API layer, and project guidance.

Review pass 1 added dependency provenance, explicit file and behavior coverage gates, a requirement coverage matrix, and the instruction not to move `.git`.

Review pass 2 fixed nested markdown fences in the README creation step so the plan renders cleanly.

Review pass 3 made the CLI version test default to `.build/debug/swiftcode` and updated the parity runner to pass `PACKAGE_BINARY`, keeping the test command consistent with the full verification command.

Review pass 4 removed references to deleted current artifacts, moved the saved plan location to `.plans`, and updated Task 1 so the `.reference` move excludes `.git`, `.reference`, and `.plans`.

Review pass 5 renamed the rewritten product to Swift Code, changed the executable and launch command to `swiftcode`, renamed Swift package targets and tests to `SwiftCode*`, and updated parity comparison to normalize the intentional `Claude Code`/`claude` reference branding to `Swift Code`/`swiftcode`.

Review pass 6 added `print_empty` and `dump_system_prompt` to the CLI comparison cases and tightened command-token rebrand normalization so domains and hyphenated identifiers are not rewritten.
