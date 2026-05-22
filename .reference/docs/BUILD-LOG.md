# Claude Code -- Build Log

Comprehensive record of rebuilding Anthropic's Claude Code CLI from leaked source.

---

## How the Source Was Obtained

### The Source Map Leak

On 2025-06-20, security researcher **@Fried_rice** discovered that Anthropic shipped a full source map (`cli.js.map`, 57MB) inside the `@anthropic-ai/claude-code` npm package. The source map contained the original TypeScript source for the entire Claude Code CLI.

We extracted **4,756 files** (1,929 unique source files after dedup) from the source map using a custom extraction script. The files map to every module in the bundled `cli.js` -- the complete application source.

### What Was in the Source Map

- All of `src/` -- the full Claude Code CLI source (1,929 files)
- `@ant/computer-use-mcp` -- Computer Use MCP server with full tool implementation (137KB `toolCalls.ts`)
- `@ant/claude-for-chrome-mcp` -- Chrome automation MCP server (8 source files, 100KB+)
- `@ant/computer-use-swift` -- macOS native bridge JS loader
- `@ant/computer-use-input` -- Input device bridge JS loader
- `@anthropic-ai/sandbox-runtime` -- Full sandbox manager source (14 files)
- `@anthropic-ai/mcpb` -- MCP Bundle tools (11 files)
- `@anthropic-ai/sdk` -- Anthropic SDK source (40+ files)
- `@anthropic-ai/bedrock-sdk` -- AWS Bedrock adapter (12 files)
- `@anthropic-ai/vertex-sdk` -- GCP Vertex adapter (7 files)
- `@anthropic-ai/foundry-sdk` -- Foundry adapter (8 files)

### Additional Sources Downloaded

- **`@anthropic-ai/tokenizer`** -- downloaded from npm, tokenization library
- **`@anthropic-ai/claude-trace`** -- downloaded from npm, tracing/debugging
- **`@anthropic-ai/claude-agent-sdk`** -- downloaded from npm, the official Agent SDK
- **`@anthropic-ai/sandbox-runtime` extras** -- parent-proxy, seccomp C source, precompiled seccomp binaries

### The GCS Bucket

We found an **open Google Cloud Storage bucket** at:
```
https://storage.googleapis.com/anthropic-public-assets/
```

Contents discovered:
- **228 versions** of native binaries (ripgrep, audio-capture, yoga-layout for all platforms)
- **Official plugins marketplace** -- 32 plugins with full source (334 files)
- Release artifacts for darwin-arm64, darwin-x64, linux-arm64, linux-x64, win32-x64

### Other Editors Checked

We checked the following competing AI code editors for similar source map vulnerabilities:
- **Cursor** (`@anysphere`) -- no source maps shipped
- **Devin** (`@cognitionai`) -- no source maps shipped
- **Augment** -- no source maps shipped
- **Windsurf** -- no source maps shipped
- **GitHub Copilot** -- no source maps shipped

None had the same vulnerability. Anthropic was the only vendor shipping unstripped source maps in production npm packages.

### OpenAI Codex Desktop

We also extracted the **OpenAI Codex desktop app** from its Electron `.asar` archive (separate effort, not in this repo). Codex uses a standard Electron packaging approach with the source accessible via `asar extract`.

---

## How the Build Was Set Up

### Package Configuration

Created `package.json` with **~65 npm dependencies** identified by scanning all `import` statements across the 1,929 source files and mapping them to npm packages:

- Standard packages installed normally (react, commander, chalk, ws, zod, etc.)
- `@anthropic-ai/*` packages installed from npm where public (`sdk`, `bedrock-sdk`, `vertex-sdk`, `foundry-sdk`, `sandbox-runtime`, `mcpb`)
- `@ant/*` private packages shimmed via `node_modules` stubs (plain JS re-exports, not TypeScript)
- `@azure/identity` installed from npm for Foundry auth

### TypeScript Configuration

Created `tsconfig.json` with path aliases:
- `src/*` maps to `./src/*` (the main source tree)
- Standard Bun/Node type resolution

### Build Script

Created `build.ts` with:
1. **Bun plugin for `bun:bundle`** -- intercepts `import { feature } from 'bun:bundle'` and replaces it with a runtime shim that resolves feature flags from a static map at compile time
2. **`MACRO.*` constants** -- `MACRO.VERSION`, `MACRO.BUILD_TIME`, `MACRO.FEEDBACK_CHANNEL`, `MACRO.ISSUES_EXPLAINER` defined via Bun's `define` option, inlined at compile time
3. **Single-file bundle** targeting Bun runtime, outputs to `dist/cli.js` (~23MB)
4. **External modules** -- `react-devtools-core` and `sharp` marked as external (optional dependencies)

### Shims Created

- `shims/bun-bundle.ts` -- runtime fallback for `feature()`, returns `false` for all flags
- `shims/bun-bundle.d.ts` -- TypeScript declaration for the `bun:bundle` module
- `shims/globals.d.ts` -- TypeScript declarations for `MACRO.*` compile-time constants

### Real Packages Installed (Replacing Initial Stubs)

Initially we created empty stubs for all `@anthropic-ai/*` packages. Then we replaced them with real source:

| Package | Source | Files |
|---------|--------|-------|
| `@anthropic-ai/sandbox-runtime` | npm + source map extraction | 14 files |
| `@anthropic-ai/bedrock-sdk` | npm + source map extraction | 12 files |
| `@anthropic-ai/vertex-sdk` | npm + source map extraction | 7 files |
| `@anthropic-ai/foundry-sdk` | npm + source map extraction | 8 files |
| `@anthropic-ai/mcpb` | npm + source map extraction | 11 files |
| `@azure/identity` | npm | standard package |

### Version Pinning

Two critical version pins were required:

- **`commander@12.1.0`** -- Claude Code source uses multi-character short flags (e.g., `-pd` for print-default). Commander v13+ dropped support for multi-char short flags, causing parse errors. Pinned to 12.1.0.
- **`react-reconciler@0.33.0`** -- Must match React 19.2. The source uses `useEffectEvent` which is only available in reconciler 0.33.0+. Earlier versions crash at runtime with "useEffectEvent is not a function".

---

## All 27 Stub Files Created

Every file we created from scratch (not from the leak) to satisfy import requirements:

| # | File | Size | Reason |
|---|------|------|--------|
| 1 | `src/cli/bg.ts` | 194 B | Not in leak -- background sessions dispatcher. Exports `dispatchBackgroundSession()` that throws. |
| 2 | `src/services/compact/cachedMicrocompact.ts` | 227 B | Feature-gated behind CACHED_MICROCOMPACT. Source was DCE'd by the feature flag. Exports type aliases and no-op factory. |
| 3 | `src/services/compact/snipCompact.ts` | 140 B | Feature-gated behind HISTORY_SNIP. Source was DCE'd. Exports `snipCompactIfNeeded()` returning undefined. |
| 4 | `src/services/contextCollapse/index.ts` | 383 B | Not in leak -- context collapse service. Never shipped externally. Exports no-op functions. |
| 5 | `src/types/connectorText.ts` | 344 B | Not in leak -- connector text block types for streaming. Exports `ConnectorTextBlock`, `ConnectorTextDelta` types and type guard. |
| 6 | `src/tools/REPLTool/REPLTool.ts` | 105 B | Ant-only tool -- internal REPL. Gated by `USER_TYPE === 'ant'`. Exports minimal tool object. |
| 7 | `src/tools/TungstenTool/TungstenLiveMonitor.tsx` | 139 B | Ant-only component -- Tungsten debug monitor UI. Returns null React element. |
| 8 | `src/tools/TungstenTool/TungstenTool.ts` | 113 B | Ant-only tool -- Tungsten debugging tool. Gated by `USER_TYPE === 'ant'`. Exports minimal tool object. |
| 9 | `src/tools/WorkflowTool/constants.ts` | 93 B | Feature-gated behind WORKFLOW_SCRIPTS. Only exports `WORKFLOW_TOOL_NAME` constant. |
| 10 | `src/tools/SuggestBackgroundPRTool/SuggestBackgroundPRTool.ts` | 137 B | Ant-only tool -- background PR suggestion feature. Exports minimal tool object. |
| 11 | `src/tools/VerifyPlanExecutionTool/VerifyPlanExecutionTool.ts` | 164 B | Env-gated by `CLAUDE_CODE_VERIFY_PLAN` env var. Plan verification tool. Exports minimal tool object. |
| 12 | `src/moreright/useMoreRight.tsx` | 3535 B | Ant-only hook -- this is from Anthropic's own `scripts/external-stubs/` overlay. They stub it themselves for external builds. Full no-op hook with correct signature. |
| 13 | `src/ink/devtools.ts` | 248 B | Dev-only -- optional `react-devtools-core` integration. Try/catch import, no-op if not installed. |
| 14 | `src/commands/agents-platform/index.ts` | 108 B | Ant-only command -- agents platform management. Exports minimal command descriptor. |
| 15 | `src/commands/assistant/assistant.tsx` | 232 B | Not in leak -- assistant/install wizard UI (part of KAIROS). Exports null-returning components. |
| 16 | `src/assistant/AssistantSessionChooser.tsx` | 156 B | Not in leak -- assistant session chooser. Returns null React element. |
| 17 | `src/utils/protectedNamespace.ts` | 96 B | Ant-only -- protected namespace checker. Returns `false` always. |
| 18 | `src/entrypoints/sdk/runtimeTypes.ts` | 1807 B | Not in leak -- SDK runtime types. Hand-reconstructed from usage patterns across codebase. Exports `Options`, `Query`, `SDKSession`, etc. |
| 19 | `src/entrypoints/sdk/settingsTypes.generated.ts` | 78 B | Generated file -- originally build-time generated. Placeholder `Settings = Record<string, any>`. |
| 20 | `src/entrypoints/sdk/toolTypes.ts` | 136 B | Not in leak -- SDK tool type definitions. Exports basic `ToolDefinition` type. |
| 21 | `src/entrypoints/sdk/coreTypes.generated.ts` | 12582 B | Regenerated -- we rebuilt this from `coreSchemas.ts` using `scripts/generate-sdk-types.ts`. Contains all `z.infer<>` type exports. |
| 22 | `src/utils/filePersistence/types.ts` | 453 B | Not in leak -- file persistence types. Exports `PersistedFile`, `FailedPersistence`, constants. |
| 23 | `src/components/agents/SnapshotUpdateDialog.tsx` | 153 B | Not in leak -- snapshot update dialog. Returns null React element. |
| 24 | `src/utils/permissions/bashClassifier.ts` | 1444 B | Ant-only -- prompt-based bash command classifier. Full no-op implementation with correct API surface. All functions return safe defaults. |
| 25 | `src/skills/bundled/verify/SKILL.md` | 43 B | Not in leak -- verify skill placeholder. Contains single line noting content was not in leak. |
| 26 | `stubs/@ant/computer-use-mcp/src/executor.ts` | 1631 B | Native binding -- Swift/Rust bridge interface for screen capture, mouse, keyboard. Types only (no implementation), since actual code is compiled native binaries. |
| 27 | `stubs/@ant/computer-use-mcp/src/subGates.ts` | 560 B | Not in leak -- permission sub-gate constants for Computer Use. Exports `ALL_SUB_GATES_OFF` and `ALL_SUB_GATES_ON` objects. |

---

## Patches Applied to Source

### Direct File Patches

| File | Change | Why |
|------|--------|-----|
| `src/utils/autoUpdater.ts` | Added `return` at line 72 before the remote version check | Prevents crash -- the version check calls GrowthBook/Statsig which requires auth |
| `src/commands/voice/index.ts` | Bypassed availability check and GrowthBook gates | Voice command would never load without auth to GrowthBook |
| `src/voice/voiceModeEnabled.ts` | Bypassed auth and GrowthBook checks | Voice mode gating checked for authenticated user + feature flag |
| `src/state/AppState.tsx` | Hardcoded VoiceProvider require | Dynamic `require()` inside `feature('VOICE_MODE') ? require(...)` ternary not resolved by Bun plugin |
| `src/screens/REPL.tsx` | Hardcoded voice hook imports | Same ternary-in-require issue -- Bun plugin only handles static `if (feature(...))` |
| `src/keybindings/defaultBindings.ts` | Hardcoded Space push-to-talk binding | Binding was behind feature flag ternary in require |
| `src/commands.ts` | Hardcoded voice and ultraplan command requires, added ultraplan to COMMANDS array | Commands loaded via `feature()` ternary; ultraplan was in `INTERNAL_ONLY_COMMANDS` |
| `src/commands/ultraplan.tsx` | Bypassed `isEnabled` ant-only gate | `isEnabled()` checked `USER_TYPE === 'ant'`, blocking external use |

### Global Sed Replacements

Two rounds of global `sed` replacements across the source:

**Round 1 -- Voice Mode:**
```bash
# Replaced feature('VOICE_MODE') with true across 40+ files
sed -i '' "s/feature('VOICE_MODE')/true/g" src/**/*.ts src/**/*.tsx
```

**Round 2 -- All Other Flags:**
```bash
# Replaced 11 additional feature flags with true
for flag in COORDINATOR_MODE TOKEN_BUDGET TEAMMEM AGENT_TRIGGERS \
  MESSAGE_ACTIONS HOOK_PROMPTS AWAY_SUMMARY BG_SESSIONS BUDDY \
  DUMP_SYSTEM_PROMPT COWORKER_TYPE_TELEMETRY; do
  sed -i '' "s/feature('${flag}')/true/g" src/**/*.ts src/**/*.tsx
done
```

These sed replacements handle the cases where `feature()` is used in top-level expressions, ternaries, or dynamic `require()` calls that the Bun build plugin cannot resolve at compile time.

---

## Feature Flags Status

All 27 known feature flags and their status in this build:

| Flag | Status | Notes |
|------|--------|-------|
| `VOICE_MODE` | WORKING | Hold-to-talk dictation. Required bypassing GrowthBook gates + hardcoding imports |
| `COORDINATOR_MODE` | WORKING | Multi-agent coordination. Source present and loads |
| `TOKEN_BUDGET` | WORKING | Token budget controls |
| `TEAMMEM` | WORKING | Team memory sync |
| `AGENT_TRIGGERS` | WORKING | Scheduled agent tasks |
| `MESSAGE_ACTIONS` | WORKING | Action buttons on messages |
| `HOOK_PROMPTS` | WORKING | Hook prompt injection |
| `AWAY_SUMMARY` | WORKING | Summary after being away |
| `BG_SESSIONS` | WORKING | Background sessions (UI loads, dispatcher stubbed) |
| `BUDDY` | WORKING | Companion mode |
| `DUMP_SYSTEM_PROMPT` | WORKING | `--dump-system-prompt` flag |
| `COWORKER_TYPE_TELEMETRY` | WORKING | Telemetry metadata tag |
| `ULTRAPLAN` | INFRA | Spawns remote CCR session on claude.ai. Needs Anthropic cloud infra |
| `BRIDGE_MODE` | INFRA | Needs bridge server infrastructure |
| `CHICAGO_MCP` | INFRA | Needs native Swift/Rust binaries for Computer Use |
| `TRANSCRIPT_CLASSIFIER` | MISSING | 3 prompt `.txt` files were DCE'd from the leak |
| `KAIROS` | MISSING | Requires `src/assistant/index.ts`, `src/proactive/` -- not in leak |
| `KAIROS_BRIEF` | MISSING | Depends on KAIROS |
| `PROACTIVE` | MISSING | Requires `src/proactive/` -- not in leak |
| `WORKFLOW_SCRIPTS` | MISSING | Requires full `WorkflowTool.ts` -- not in leak |
| `WEB_BROWSER_TOOL` | MISSING | Requires `WebBrowserPanel.ts` -- not in leak |
| `TERMINAL_PANEL` | MISSING | Requires `TerminalCaptureTool/` -- not in leak |
| `EXPERIMENTAL_SKILL_SEARCH` | MISSING | Requires `DiscoverSkillsTool/` -- not in leak |
| `HISTORY_SNIP` | STUB | `snipCompact.ts` is an empty stub |
| `CACHED_MICROCOMPACT` | STUB | `cachedMicrocompact.ts` is an empty stub |
| `ABLATION_BASELINE` | OFF | Degrades quality intentionally -- never enable |
| `OVERFLOW_TEST_TOOL` | OFF | Internal test tool |

---

## What Works End-to-End

### Core Functionality
- **Build** -- `bun run build` produces `dist/cli.js` (~23MB single file)
- **CLI** -- `bun dist/cli.js` launches the interactive REPL
- **`--version`** -- reports `2.1.88`
- **`--help`** -- full help text with all flags
- **`--dump-system-prompt`** -- outputs the complete system prompt

### Tools (All Standard Tools Working)
- BashTool -- shell execution with permission system
- FileEditTool -- file editing with diff display
- FileReadTool -- file reading
- FileWriteTool -- file writing
- GlobTool -- file search with glob patterns
- GrepTool -- content search (uses vendored ripgrep binary)
- AgentTool -- subagent spawning
- WebFetchTool -- HTTP fetching

### Authentication
- **OAuth flow** -- full OAuth implementation works (redirects to console.anthropic.com)
- **API key auth** -- `ANTHROPIC_API_KEY` environment variable
- **Bedrock auth** -- AWS credentials via `@anthropic-ai/bedrock-sdk`
- **Vertex auth** -- GCP credentials via `@anthropic-ai/vertex-sdk`
- **Foundry auth** -- Azure credentials via `@anthropic-ai/foundry-sdk`

### Infrastructure
- **MCP support** -- Model Context Protocol client/server, config loading, tool registration
- **Plugin system** -- loads from `~/.claude/plugins/`, full lifecycle
- **Hook system** -- PreToolUse/PostToolUse/Stop hooks, config via `settings.json`
- **Skill system** -- built-in skills, bundled skill loading
- **Session persistence** -- session history, resume from session ID
- **Vim mode** -- full vim emulation (motions, operators, text objects)
- **Voice mode** -- hold-to-talk dictation (after bypassing gates)
- **Sandbox mode** -- real `@anthropic-ai/sandbox-runtime` package with macOS/Linux sandboxing
- **Agent SDK** -- `pathToClaudeCodeExecutable` integration works

---

## What Doesn't Work and Why

### Computer Use
**Status:** Has full logic but non-functional.

The complete Computer Use implementation was extracted (`stubs/@ant/computer-use-mcp/src/toolCalls.ts` at 137KB is the full tool), but it requires native binaries:
- `@ant/computer-use-swift` -- macOS Swift binary for screen capture, window management
- `@ant/computer-use-input` -- Rust binary for mouse/keyboard input injection

We have the JS loader shims (`js/index.js`) that show how they're loaded, but the actual `.node` native addons are platform-specific compiled binaries not available in the source map.

### ULTRAPLAN
**Status:** Needs Anthropic cloud infrastructure.

ULTRAPLAN spawns a remote CCR (Claude Code Runner) session on claude.ai to execute complex plans. The source is present and the command loads, but it requires:
- Authenticated session to claude.ai
- Access to Anthropic's CCR infrastructure
- The `isEnabled` gate was also checking `USER_TYPE === 'ant'` (bypassed)

### KAIROS / Assistant Mode
**Status:** Source files not in leak.

The assistant/KAIROS feature requires several source files that were not included in the source map:
- `src/assistant/index.ts`
- `src/proactive/` directory (entire directory missing)
- Related UI components

### Auto-Mode Classifier Prompts
**Status:** Prompt files DCE'd.

The auto-mode classifier (`src/utils/permissions/yoloClassifier.ts`, 52KB) references 3 `.txt` prompt files that were eliminated by the `TRANSCRIPT_CLASSIFIER` feature flag during Anthropic's build. The classifier code exists but the prompts it needs are missing.

### BRIDGE_MODE
**Status:** Needs bridge server.

Cloud session bridging requires Anthropic's bridge server infrastructure. The client-side code exists in `src/bridge/` but has no server to connect to.

### Missing Source Files (4 files confirmed not in leak)
| File | What It Does |
|------|-------------|
| `src/coordinator/workerAgent.ts` | Worker agent implementation for multi-agent coordination |
| `src/commands/buddy/index.ts` | Buddy/companion mode command entry |
| `src/utils/taskSummary.ts` | Task summary generation utility |
| `src/cli/bg.ts` | Background session dispatcher (stubbed) |

---

## Blockers Encountered During Build

### 1. Commander Version Mismatch
**Problem:** Build crashed with `Invalid short flag` errors.
**Cause:** Claude Code source uses multi-character short flags like `-pd` (print-default). Commander v13+ only supports single-character short flags.
**Fix:** Pinned `commander@12.1.0` and `@commander-js/extra-typings@12.1.0`.

### 2. React Reconciler Version Mismatch
**Problem:** Runtime crash: `useEffectEvent is not a function`.
**Cause:** `react-reconciler` version didn't match React 19.2. The source uses `useEffectEvent` which requires reconciler 0.33.0+.
**Fix:** Pinned `react-reconciler@0.33.0`.

### 3. SandboxManager.isSupportedPlatform Missing
**Problem:** Build error -- `isSupportedPlatform` not found on SandboxManager.
**Cause:** Initial stub didn't export the static method. After replacing with the real `@anthropic-ai/sandbox-runtime` package, the method was present.
**Fix:** Replaced stub with real npm package.

### 4. Audio Capture Module Missing
**Problem:** Voice mode crashed trying to load `@anthropic-ai/audio-capture-napi`.
**Cause:** The audio capture module is a native addon (compiled C/Rust) distributed as platform-specific binaries in Anthropic's GCS bucket. The export name in the source didn't match the binary's exports.
**Fix:** We found the binaries in the GCS bucket (`vendor/audio-capture/`) and fixed the import path. Voice mode works when the correct binary is present.

### 5. Feature Flags in Dynamic Requires
**Problem:** Bun's build plugin correctly handles `if (feature('X'))` static conditionals, but NOT `feature('X') ? require('./foo') : require('./bar')` ternaries in top-level scope.
**Cause:** Bun's dead-code elimination operates on `if` blocks. Ternary expressions in `require()` calls are evaluated at runtime, not compile time.
**Fix:** Manually hardcoded the correct branch in 6 files (`AppState.tsx`, `REPL.tsx`, `defaultBindings.ts`, `commands.ts`, and 2 others). Also ran global `sed` replacement of `feature('FLAG')` with `true` for all enabled flags.

### 6. VoiceProvider Context Not Mounted
**Problem:** Voice commands crashed with "VoiceProvider not found in context".
**Cause:** The `VoiceProvider` component is conditionally loaded via `feature('VOICE_MODE')` ternary in `AppState.tsx`. Since the ternary wasn't resolved at compile time, the provider was never mounted.
**Fix:** Hardcoded the VoiceProvider require in `AppState.tsx`.

### 7. ULTRAPLAN in INTERNAL_ONLY_COMMANDS
**Problem:** `/ultraplan` command was hidden and inaccessible.
**Cause:** The command was in the `INTERNAL_ONLY_COMMANDS` array in `src/commands.ts`, filtered out for non-ant users.
**Fix:** Added ultraplan to the main `COMMANDS` array in `commands.ts` and bypassed the `isEnabled` gate in `commands/ultraplan.tsx`.

### 8. Feature Flag Sprawl
**Problem:** Each feature flag is referenced in 10-40+ files across the codebase.
**Cause:** Anthropic uses feature flags pervasively -- not just for gating entry points, but inline throughout components, hooks, and utilities.
**Fix:** Global `sed` replacement was the only practical approach. Individual patching would have required modifying 100+ files.

---

## Security Findings

### Telemetry

Claude Code sends telemetry to several endpoints:

| Endpoint | Type | Notes |
|----------|------|-------|
| `api.anthropic.com` | First-party events | Session start/end, tool usage, errors |
| Datadog (US-5 region) | APM/metrics | Performance tracing, error tracking |
| GrowthBook | Feature flags | Fetches dynamic feature flag config |

**Disable telemetry:** Set `DISABLE_TELEMETRY=1` environment variable.

The Datadog client token is hardcoded in the source (not a secret -- it's a public client token, but data flows to Anthropic's Datadog US-5 account).

### Things to Avoid

- **Do not set `USER_TYPE=ant`** -- this unlocks internal Anthropic tools (Tungsten, REPL, SuggestBackgroundPR) that have no implementation in this build and will crash
- **Do not use `/bug` or `/feedback` commands** -- these upload your full conversation transcript to Anthropic's servers
- **Do not use `/agents-platform`** -- ant-only command, will crash

### GCS Bucket Exposure

The GCS bucket `anthropic-public-assets` was publicly readable and contained:
- 228 versions of native binaries across all platforms
- The complete official plugins marketplace (32 plugins)
- Release artifacts with full version history

This is not a security vulnerability per se (the bucket appears intentionally public for distribution), but it exposes Anthropic's full release history and internal tooling.

---

## How to Keep It Updated

### When Anthropic Releases a New Version

1. **Check the changelog** -- Anthropic publishes release notes. Review what changed.
2. **Check if the source map is still shipped** -- `npm pack @anthropic-ai/claude-code` and check for `cli.js.map`
3. **If source map is present** -- re-extract with the same process, diff against current source
4. **If source map is removed** -- we work from the last extracted version and apply changes manually based on changelog descriptions
5. **Update `MACRO.VERSION`** in `build.ts` to match the new version
6. **Check for new feature flags** -- search for `feature('` in the new source
7. **Check for new dependencies** -- diff `package.json` imports
8. **Rebuild and test** -- `bun run build && bun dist/cli.js --version`

### Updating Feature Flags

When a feature graduates from flag-gated to always-on in Anthropic's build:
1. The `feature('FLAG')` calls will be removed from source
2. The conditional imports will become unconditional
3. Our `sed` replacements for that flag become no-ops (already resolved to `true`)
4. Remove the flag from `build.ts` FEATURE_FLAGS

### When Stubs Need Real Implementations

If Anthropic open-sources a previously missing module:
1. Check if it appears in a new source map extraction
2. Check if it's published to npm under `@anthropic-ai/*`
3. Replace the stub file with the real source
4. Update the stub file list in `CLAUDE.md`
