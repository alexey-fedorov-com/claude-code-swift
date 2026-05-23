# Terminal UI Parity Contract

## Goal

The Swift implementation of the terminal UI produces visually equivalent
output to `.reference` Claude Code for the common interactive paths
(welcome, prompt input, message rendering, spinner, key dialogs).

## Architectural deviations from reference

The reference TypeScript uses a custom React reconciler ("custom Ink fork")
with a 5,000-line `REPL.tsx` and ~300 components. A literal 1:1 port is
months of work. This implementation takes a different approach:

- **No React, no reconciler.** Each frame, the app re-renders the full view
  tree from immutable state and diffs against the previous frame to emit
  minimal ANSI updates. See `SwiftCodeTerminalUI/App/App.swift`.
- **Custom Yoga port.** The flexbox layout calculator
  (`SwiftCodeTerminalUI/Yoga/`) supports flexDirection, justifyContent,
  alignItems, alignSelf, padding/margin, gap, flexGrow, percentage widths,
  and display:none. Not full Yoga spec — additions land as features need
  them.
- **Single theme.** Default dark theme baked in. Apple_Terminal and light
  theme variants from `WelcomeV2.tsx` are not ported.
- **Event-loop architecture.** A background `Thread` reads raw key events
  from stdin and posts them to the `App` actor. The actor serializes state
  mutations and renders. See `SwiftCodeTerminalUI/App/EventLoop.swift`.

## Components shipped

| Component | File | Test |
|-----------|------|------|
| Screen + ANSIRenderer (diff) | `Renderer/Screen.swift`, `Renderer/ScreenDiff.swift`, `Renderer/ANSIEscapes.swift` | `ScreenDiffTests`, `AnsiEscapesTests`, `StyleTableTests` |
| Text wrap (word-aware, CJK width) | `Renderer/TextWrap.swift` | `TextWrapTests` |
| Yoga layout (flex, gap, alignSelf, display) | `Yoga/*.swift` | `YogaLayoutTests` |
| Theme tokens (Claude orange + 8 semantic) | `Theme/Theme.swift` | `ViewSnapshotTests` |
| Box, Text, Spinner, Newline, Spacer | `Components/Box.swift`, `Text.swift`, `Spinner.swift`, `Newline.swift`, `Spacer.swift` | `ViewSnapshotTests` |
| App actor + EventLoop + AppLifecycle | `App/App.swift`, `App/EventLoop.swift`, `App/AppLifecycle.swift` | `EventLoopTests` |
| Welcome banner (dark Clawd ASCII) | `Components/Welcome/clawd-art.swift`, `WelcomeBanner.swift` | `WelcomeBannerTests` |
| PromptInput + Cursor + Footer | `Components/PromptInput/*.swift` | `PromptInputTests` |
| Message renderers (User, Assistant, System, List) | `Components/Messages/*.swift` | `MessageRenderingTests` |
| ChatScreen composition | `ChatScreen.swift` | `ChatScreenTests` |
| Confirm + PermissionRequest dialogs | `Components/Dialogs/*.swift` | `DialogTests` |
| InteractiveREPL (TUI-driven) | `SwiftCodeCLI/InteractiveREPL.swift` | (smoke-tested manually) |

## Deferred (known scope omissions)

These reference components are not yet ported. Each is a future task before
the corresponding flow can ship:

- **Welcome banner variants.** Light theme, Apple_Terminal-specific layout.
- **PromptInput sub-features.** Vim mode, IDE selection mentions, paste image
  refs, fast mode picker, thinking toggle, history search, *fuzzy* command
  suggestions (prefix-only shipped in Task 12).
- ~~**Slash command autocomplete**~~ — shipped (Task 12). Prefix-match against
  registered commands; Up/Down/Tab/Enter routing in the reducer.
- ~~**File `@`-mention autocomplete**~~ — shipped (Task 13). Filesystem walk via
  `SwiftCodeNative.PathCompletion`; directories insert with trailing `/`, files
  with trailing space. No LRU cache (single shallow scan per keystroke).
- **MessageSelector** (resume / jump-to).
- **HighlightedCode** (markdown rendering + syntax highlighting).
- **FileEditToolDiff** (per-tool result UI for diffs).
- **AgentProgressLine**, **CoordinatorAgentStatus**, **Tasks dialog**.
- **MCP elicitation dialog**, **OAuth flow UI**, **Bridge dialog**.
- **ResumeConversation**, **ExportDialog**, **ExitFlow**.
- **Notifications surface** (`PromptInput/Notifications.tsx`).
- **Streaming output rendering.** Assistant text currently lands all-at-once
  after the response completes; the reference streams character-by-character.

## Snapshot normalization

Tests use `renderViewToScreen(view, width:, height:)` which produces a
deterministic `Screen` of cells (character + style id). Test code converts
to a row-wise text representation for assertions.

- Trailing spaces stripped before comparison
- Cursor position not embedded (handled by App's terminal cursor positioning)
- Spinner frame fixed via explicit `frameIndex:` parameter
- Dynamic strings (version, cwd) passed in as parameters so tests stay
  reproducible

## Known limitations

- `WrappedTextView` mutates `layoutHeight` during paint after Yoga's layout
  pass. Acceptable for transcripts (each message followed by NewlineView)
  but parents that read child layout heights post-paint may see stale
  values. A proper measure phase is a future task.
- `EventLoop.stop()` sets a flag but doesn't unblock the reader thread
  (blocking `read()`). Acceptable because shutdown happens via signal
  handlers (`AppLifecycle.installSignalHandlers`), not graceful stop.
- `SuggestionOverlay` is shipped as a primitive but not yet wired to the
  PromptInput (Tasks 12 and 13 will wire it).

## Implementation summary

13 tasks completed (Tasks 1-13 of `docs/superpowers/plans/2026-05-23-terminal-ui-parity.md`):

| # | Task | Commit |
|---|------|--------|
| 1 | Screen buffer + ANSI diff renderer | `891a986` (+ `5475c86` lock fix) |
| 2 | Text wrap + width measurement | `be0d144` |
| 3 | Yoga extensions | `b862ffa` |
| 4 | Theme + View protocol + Box/Text/Spinner | `1e04179` |
| 5 | App actor + EventLoop + Lifecycle | `f798253` (+ `5703051` diff path, `68a0893` doc) |
| 6 | Welcome banner | `668c90a` (+ `01bafa9` t16 width fix) |
| 7 | PromptInput | `e476107` |
| 8 | Message renderers | `766bd61` |
| 9 | ChatScreen + REPL rewrite | `8fbb2c6` |
| 10 | Dialogs | `bd2c34b` |
| 11 | Contract doc + verification | `bb01de7` |
| 12 | Slash command autocomplete | `2aba2c1` |
| 13 | File `@`-mention autocomplete | `a5e8d33` |
