# UI Parity Contract

Status: **Scaffolded (Task 10).** Full parity with the reference TypeScript/Ink renderer is aspirational and
will be built incrementally in Tasks 13–15.

---

## What's Implemented (Task 10)

### Yoga Layout Engine (`SwiftCodeTerminalUI/Yoga/`)

| Feature | Status | Notes |
|---|---|---|
| Fixed width / height | ✅ | `Dimension.fixed(Int)` |
| Auto width / height from content | ✅ | Measures text width |
| Percent width / height | ✅ | 0.0–1.0 fraction of parent |
| Padding (EdgeInsets) | ✅ | Top/right/bottom/left |
| Margin (EdgeInsets) | ✅ | Top/right/bottom/left |
| FlexDirection: row / column | ✅ | |
| JustifyContent: start/center/end/spaceBetween/spaceAround | ✅ | |
| AlignItems: start/center/end/stretch | ✅ | |
| minWidth / maxWidth | ✅ | |
| flexGrow | ❌ | Not computed (deferred) |
| flexShrink | ❌ | Not computed (deferred) |
| flexBasis | ❌ | Not computed (deferred) |
| Wrap | ❌ | No line wrapping (deferred) |
| Absolute positioning | ❌ | Deferred |

### Renderer (`SwiftCodeTerminalUI/Renderer/`)

| Feature | Status | Notes |
|---|---|---|
| 2D string canvas | ✅ | `Canvas` struct with row×col buffer |
| Text node rendering at computed position | ✅ | |
| ANSI color (fg, 30–37, 90–97) | ✅ | `ANSIColor` |
| ANSI background (bg, 40–47) | ✅ | |
| Bold / italic / underline / dim | ✅ | |
| Box border: single / double / rounded | ✅ | |
| Screen clear + cursor control | ✅ | `TerminalOutput` |
| Full-screen re-render loop | ✅ | `renderFrame()` |
| Cursor-positioned streaming writes | ❌ | Canvas approach used instead |
| True color (RGB) | ❌ | Deferred |
| 256-color palette | ❌ | Deferred |
| Wide character (CJK/emoji) width | ❌ | Deferred |
| ANSI stripping | ❌ | Deferred |

### Events (`SwiftCodeTerminalUI/Events/`)

| Feature | Status | Notes |
|---|---|---|
| ASCII characters | ✅ | |
| Control characters (Ctrl+A–Z) | ✅ | |
| Escape | ✅ | |
| Arrow keys (CSI + SS3) | ✅ | |
| Shift+arrows | ✅ | |
| Backspace / Delete | ✅ | |
| Function keys F1–F12 | ✅ | |
| Focus / blur | ✅ | ESC[I / ESC[O |
| Bracketed paste (ESC[200~…ESC[201~) | ✅ | |
| Window resize (SIGWINCH) | ❌ | Signal handler deferred |
| Mouse events | ❌ | Deferred |
| Non-blocking read loop | ❌ | Uses blocking read(); wrap in Task for async |
| Raw mode enable/disable | ✅ | `TerminalRawMode` (POSIX) |

### Components (`SwiftCodeTerminalUI/Components/`)

| Component | Status | Notes |
|---|---|---|
| TextComponent | ✅ | Text with ANSI styling |
| BoxComponent | ✅ | Flex container + optional border |
| Spinner | ✅ | Braille frames, label, optional color |
| SelectInput | ❌ | Task 15 |
| TextInput | ❌ | Task 15 |
| Confirm | ❌ | Task 15 |
| MultiSelect | ❌ | Task 15 |

---

## Reference: TypeScript/Ink Renderer

The reference implementation is a custom React-compatible terminal renderer in
`.reference/src/ink/` with ~100 component files under `.reference/src/components/`.

### Key differences vs reference

1. **No React/hooks**: The Swift implementation is imperative — callers build `YogaNode` trees
   directly and run `YogaCalculator.calculate(root:availableWidth:availableHeight:)`.

2. **No virtual DOM / reconciliation**: There is no diff engine. Full re-renders repaint
   the entire canvas. This is fine for a first pass.

3. **No state management**: No `useState` / `useEffect` / `useReducer`. State lives in the
   caller; they rebuild the node tree and re-render each frame.

4. **2D buffer vs streaming cursor writes**: The reference emits cursor-positioned escape
   codes incrementally. The Swift renderer uses a 2D `Canvas`, then joins rows with `\n`.
   This is simpler but may flicker on large terminals — addressed by `clearAndHome()` in
   `TerminalOutput`.

---

## Path to Full Parity

- **Task 13** — port tool-specific UI components (progress bars, diffs, file lists)
- **Task 14** — slash command UI (command palette, autocomplete)
- **Task 15** — interactive REPL loop: wraps `InputReader`, drives re-render loop,
  builds full-screen TUI on top of this scaffold
- **Task 16** — output styles (cost display, thinking blocks, code blocks, streaming)

The current scaffold in Task 10 is intentionally minimal. It provides the lowest layer that
Tasks 13–16 can build on without pulling in React, SwiftUI, or any third-party UI framework.
