# Terminal UI Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current line-based REPL with a real interactive terminal UI that visually matches `.reference` Claude Code on the common paths — welcome screen, bordered prompt input, message rendering, spinner, and the most-used dialogs.

**Architecture:** Skip a full React/Ink reconciler port (~13k LoC of custom Ink + 5k-line REPL). Instead, use an Elm-style update loop in `SwiftCodeTerminalUI`: each frame, the app composes an immutable `View` tree (Box/Text/Spinner), `Yoga` lays it out, `Renderer` paints into a `Screen` buffer, then diffs against the previous frame and writes only the changed cells to stdout with ANSI cursor positioning. Input is read in raw mode from a dedicated thread and pushed onto a `MainSerialExecutor`-style queue consumed by the app actor. The REPL is rewritten as a `ChatScreen` view rendered each frame from state.

**Tech Stack:** Swift 6 actors, POSIX termios for raw mode, ANSI escape sequences (SGR + CSI cursor + alt-screen + bracketed paste + DECSET), Foundation `Pipe`/`FileHandle` for IO, no external UI deps.

**Out of scope for this plan (intentional, ship later):**
- React-style component diffing / reconciler — we do whole-tree re-render + screen diff
- Mouse/click events beyond focus
- Markdown / syntax-highlighted code rendering (assistant text rendered as plain text with basic ANSI)
- IDE / Voice / Swarm / Vim / Teammate UI surfaces (their state isn't wired up)
- The 100+ niche dialogs in `.reference/src/components/` — we ship Welcome, PromptInput, ChatScreen, Spinner, Confirm dialog, PermissionRequest dialog. Others are deferred.
- `figures` / `chalk` ports — we hard-code the few glyphs we need
- Theme switching at runtime — single dark theme baked in (matches default)

These omissions are documented in `docs/parity/ui-contract.md` (Task 9). Future plans can add more components.

---

## File Structure

**New / rewritten under `Sources/SwiftCodeTerminalUI/`:**

| Path | Responsibility |
|------|----------------|
| `Renderer/Screen.swift` | 2D cell grid (char + style id) — the canonical paintable buffer |
| `Renderer/ScreenDiff.swift` | Compares prev/next Screen, emits cursor-positioned ANSI updates |
| `Renderer/StyleTable.swift` | Interns SGR styles (color, bold, dim, etc.) — emits cell style ids |
| `Renderer/ANSIEscapes.swift` | All escape sequence constants/builders (cursor, alt-screen, SGR, paste, focus) |
| `Renderer/PaintContext.swift` | Walks layout tree → writes cells into Screen with absolute coords |
| `Renderer/TextWrap.swift` | Word-wrapping that respects ANSI width (treats CJK as width=2) |
| `Yoga/YogaNode.swift` *(modify)* | Add `flexGrow`, `flexShrink`, `gap`, `alignSelf`, `position`, `display:none` |
| `Yoga/YogaCalculator.swift` *(modify)* | Implement grow/shrink, gap, alignSelf, content-shrink behaviour |
| `Components/View.swift` | `View` protocol — `func body() -> AnyNode` style; `BoxView`, `TextView`, `SpinnerView`, `AnyView` |
| `Components/Text.swift` *(rewrite)* | Text with full color/dim/bold/underline/italic/strikethrough/inverse |
| `Components/Box.swift` *(rewrite)* | Box with full flex props, gap, overflow:hidden, position:absolute |
| `Components/Spinner.swift` *(rewrite)* | Animated frame index pulled from app clock |
| `Components/Newline.swift` | Forces a row break |
| `Components/Spacer.swift` | flex:1 cross-axis spacer |
| `Theme/Theme.swift` | Theme struct + default dark theme + named color tokens (`claude`, `clawd_body`, etc.) |
| `App/App.swift` | Actor that owns app state, runs the frame loop, dispatches input |
| `App/EventLoop.swift` | RunLoop integration: reads from `InputReader` on a thread, posts events to actor |
| `App/AppLifecycle.swift` | Setup/teardown: alt-screen on/off, raw mode on/off, SIGWINCH handler, exit cleanup |
| `Components/PromptInput/Cursor.swift` | Cursor state (text + offset) with insert/delete/move helpers |
| `Components/PromptInput/PromptInput.swift` | Multi-line bordered editor view |
| `Components/PromptInput/PromptInputFooter.swift` | Mode indicator + shortcut hints |
| `Components/Welcome/WelcomeBanner.swift` | Static welcome view with Clawd ASCII art |
| `Components/Welcome/clawd-art.swift` | Hardcoded multi-line art constants ported from `WelcomeV2.tsx` |
| `Components/Messages/MessageList.swift` | Renders the chat transcript above the input |
| `Components/Messages/UserMessage.swift` | `> {text}` rendering with proper indent |
| `Components/Messages/AssistantMessage.swift` | `● {text}` rendering with word-wrap and orange marker |
| `Components/Messages/SystemMessage.swift` | Dim italic system / status |
| `Components/Dialogs/Confirm.swift` | Yes/No prompt dialog overlay |
| `Components/Dialogs/PermissionRequest.swift` | Tool permission dialog matching `.reference/src/components/permissions/PermissionRequest.tsx` |
| `ChatScreen.swift` | Top-level view composing MessageList + PromptInput + Spinner + footer |

**Rewritten / modified under `Sources/SwiftCodeCLI/`:**

| Path | Responsibility |
|------|----------------|
| `InteractiveREPL.swift` *(rewrite)* | Bootstraps `App`, registers input handlers, drives a `ChatScreen` from state. Removes `printBanner` / `readLine` loop. |

**New tests:**

| Path | What it covers |
|------|----------------|
| `Tests/SwiftCodeTerminalUITests/ScreenDiffTests.swift` | Diff emits minimal cursor-positioned updates |
| `Tests/SwiftCodeTerminalUITests/StyleTableTests.swift` | SGR open/close strings; dedup interning |
| `Tests/SwiftCodeTerminalUITests/TextWrapTests.swift` | Word-wrap edge cases, CJK width |
| `Tests/SwiftCodeTerminalUITests/YogaLayoutTests.swift` *(extend)* | flexGrow, gap, alignSelf, percentage widths |
| `Tests/SwiftCodeTerminalUITests/PromptInputTests.swift` | Cursor moves, insert/delete, multi-line wrap |
| `Tests/SwiftCodeTerminalUITests/WelcomeBannerTests.swift` | Welcome view paints expected rows (snapshot equality vs golden text) |
| `Tests/SwiftCodeTerminalUITests/ChatScreenTests.swift` | Full screen snapshot for empty / one-message states |
| `Tests/SwiftCodeTerminalUITests/EventLoopTests.swift` | Input events dispatched in order; resize handled |
| `Tests/SwiftCodeTerminalUITests/AnsiEscapesTests.swift` | Exact byte sequences for cursor, alt-screen, SGR |

---

## Requirement Coverage

| Requirement (user-stated goal) | Tasks |
|---|---|
| Welcome screen matches `.reference` WelcomeV2 dark variant | 6 |
| Prompt input is a rounded-border box, multi-line, with footer | 7 |
| Messages render inline above input with `>` / `●` markers and word wrap | 8 |
| Real interactive UI: raw mode, alt-screen, repaint, keypress dispatch | 1, 2, 5 |
| Layout matches reference (flex grow, gap, percentage widths) | 3 |
| Theme colors (Claude orange, clawd_body) match reference | 4 |
| Spinner animates while assistant is responding | 8, 9 |
| At least one permission dialog (Confirm + PermissionRequest) | 10 |
| REPL replaced with TUI; no more chunky ASCII banner | 9 |
| Coverage doc + snapshot baseline | 11 |

---

## Task 1: Build The Screen Buffer And ANSI Diff Renderer

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/Renderer/ANSIEscapes.swift`
- Create: `Sources/SwiftCodeTerminalUI/Renderer/StyleTable.swift`
- Create: `Sources/SwiftCodeTerminalUI/Renderer/Screen.swift`
- Create: `Sources/SwiftCodeTerminalUI/Renderer/ScreenDiff.swift`
- Test: `Tests/SwiftCodeTerminalUITests/AnsiEscapesTests.swift`
- Test: `Tests/SwiftCodeTerminalUITests/StyleTableTests.swift`
- Test: `Tests/SwiftCodeTerminalUITests/ScreenDiffTests.swift`

- [ ] **Step 1: Write failing test for ANSIEscapes constants**

`Tests/SwiftCodeTerminalUITests/AnsiEscapesTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class AnsiEscapesTests: XCTestCase {
    func testCursorPosition() {
        // row 1, col 1 in terminal coordinates (1-based)
        XCTAssertEqual(ANSIEscapes.cursorTo(row: 1, col: 1), "\u{1B}[1;1H")
        XCTAssertEqual(ANSIEscapes.cursorTo(row: 10, col: 25), "\u{1B}[10;25H")
    }

    func testAltScreen() {
        XCTAssertEqual(ANSIEscapes.enterAltScreen, "\u{1B}[?1049h")
        XCTAssertEqual(ANSIEscapes.exitAltScreen, "\u{1B}[?1049l")
    }

    func testCursorVisibility() {
        XCTAssertEqual(ANSIEscapes.hideCursor, "\u{1B}[?25l")
        XCTAssertEqual(ANSIEscapes.showCursor, "\u{1B}[?25h")
    }

    func testClearScreen() {
        XCTAssertEqual(ANSIEscapes.clearScreen, "\u{1B}[2J")
        XCTAssertEqual(ANSIEscapes.clearLine, "\u{1B}[2K")
    }

    func testBracketedPaste() {
        XCTAssertEqual(ANSIEscapes.enableBracketedPaste, "\u{1B}[?2004h")
        XCTAssertEqual(ANSIEscapes.disableBracketedPaste, "\u{1B}[?2004l")
    }

    func testSgrReset() {
        XCTAssertEqual(ANSIEscapes.sgrReset, "\u{1B}[0m")
    }
}
```

- [ ] **Step 2: Run, verify it fails**

```bash
swift test --filter AnsiEscapesTests
```

Expected: FAIL (`ANSIEscapes` undefined).

- [ ] **Step 3: Implement ANSIEscapes**

`Sources/SwiftCodeTerminalUI/Renderer/ANSIEscapes.swift`:

```swift
public enum ANSIEscapes {
    public static let esc = "\u{1B}"
    public static let csi = "\u{1B}["
    public static func cursorTo(row: Int, col: Int) -> String { "\(csi)\(row);\(col)H" }
    public static let enterAltScreen = "\(csi)?1049h"
    public static let exitAltScreen = "\(csi)?1049l"
    public static let hideCursor = "\(csi)?25l"
    public static let showCursor = "\(csi)?25h"
    public static let clearScreen = "\(csi)2J"
    public static let clearLine = "\(csi)2K"
    public static let enableBracketedPaste = "\(csi)?2004h"
    public static let disableBracketedPaste = "\(csi)?2004l"
    public static let enableFocusEvents = "\(csi)?1004h"
    public static let disableFocusEvents = "\(csi)?1004l"
    public static let sgrReset = "\(csi)0m"
    public static let saveCursor = "\(csi)s"
    public static let restoreCursor = "\(csi)u"
}
```

- [ ] **Step 4: Run, verify pass**

```bash
swift test --filter AnsiEscapesTests
```

Expected: PASS.

- [ ] **Step 5: Write failing test for StyleTable**

`Tests/SwiftCodeTerminalUITests/StyleTableTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class StyleTableTests: XCTestCase {
    func testDefaultStyleHasIdZero() {
        let table = CellCellStyleTable()
        XCTAssertEqual(table.id(for: .default), 0)
    }

    func testInterningReturnsSameId() {
        let table = CellCellStyleTable()
        let style = CellStyle(fg: .rgb(215, 119, 87), bold: true)
        let id1 = table.id(for: style)
        let id2 = table.id(for: style)
        XCTAssertEqual(id1, id2)
    }

    func testSgrOpenForRgbForeground() {
        let style = CellStyle(fg: .rgb(215, 119, 87))
        XCTAssertEqual(style.sgrOpen(), "\u{1B}[38;2;215;119;87m")
    }

    func testSgrOpenForBoldDim() {
        let style = CellStyle(bold: true, dim: true)
        // bold=1, dim=2
        XCTAssertEqual(style.sgrOpen(), "\u{1B}[1;2m")
    }

    func testSgrOpenEmptyForDefault() {
        XCTAssertEqual(CellStyle.default.sgrOpen(), "")
    }

    func testSgrOpenForAnsi256Background() {
        let style = CellStyle(bg: .ansi256(160))
        XCTAssertEqual(style.sgrOpen(), "\u{1B}[48;5;160m")
    }
}
```

- [ ] **Step 6: Run, verify it fails**

```bash
swift test --filter StyleTableTests
```

Expected: FAIL.

- [ ] **Step 7: Implement CellStyle + StyleTable**

`Sources/SwiftCodeTerminalUI/Renderer/StyleTable.swift`:

```swift
public enum CellColor: Hashable, Sendable {
    case `default`
    case ansi16(Int)       // 30-37 / 90-97
    case ansi256(Int)      // 0-255
    case rgb(UInt8, UInt8, UInt8)
}

public struct CellStyle: Hashable, Sendable {
    public var fg: CellColor
    public var bg: CellColor
    public var bold: Bool
    public var dim: Bool
    public var italic: Bool
    public var underline: Bool
    public var inverse: Bool
    public var strikethrough: Bool

    public init(fg: CellColor = .default, bg: CellColor = .default,
                bold: Bool = false, dim: Bool = false, italic: Bool = false,
                underline: Bool = false, inverse: Bool = false, strikethrough: Bool = false) {
        self.fg = fg; self.bg = bg; self.bold = bold; self.dim = dim
        self.italic = italic; self.underline = underline
        self.inverse = inverse; self.strikethrough = strikethrough
    }

    public static let `default` = CellStyle()

    public func sgrOpen() -> String {
        var codes: [String] = []
        if bold { codes.append("1") }
        if dim { codes.append("2") }
        if italic { codes.append("3") }
        if underline { codes.append("4") }
        if inverse { codes.append("7") }
        if strikethrough { codes.append("9") }
        switch fg {
        case .default: break
        case .ansi16(let n): codes.append("\(n)")
        case .ansi256(let n): codes.append("38;5;\(n)")
        case .rgb(let r, let g, let b): codes.append("38;2;\(r);\(g);\(b)")
        }
        switch bg {
        case .default: break
        case .ansi16(let n): codes.append("\(n + 10)")
        case .ansi256(let n): codes.append("48;5;\(n)")
        case .rgb(let r, let g, let b): codes.append("48;2;\(r);\(g);\(b)")
        }
        return codes.isEmpty ? "" : "\(ANSIEscapes.csi)\(codes.joined(separator: ";"))m"
    }
}

public final class CellStyleTable {
    public typealias StyleID = Int
    private var styleToId: [CellStyle: StyleID] = [.default: 0]
    private var idToStyle: [CellStyle] = [.default]

    public init() {}

    public func id(for style: CellStyle) -> StyleID {
        if let id = styleToId[style] { return id }
        let id = idToStyle.count
        idToStyle.append(style)
        styleToId[style] = id
        return id
    }

    public func style(for id: StyleID) -> CellStyle {
        guard id >= 0 && id < idToStyle.count else { return .default }
        return idToStyle[id]
    }
}
```

- [ ] **Step 8: Run, verify pass**

```bash
swift test --filter StyleTableTests
```

Expected: PASS.

- [ ] **Step 9: Write failing test for Screen + ScreenDiff**

`Tests/SwiftCodeTerminalUITests/ScreenDiffTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class ScreenDiffTests: XCTestCase {
    func testEmptyDiffIsEmpty() {
        let a = Screen(width: 5, height: 2)
        let b = Screen(width: 5, height: 2)
        XCTAssertEqual(ScreenDiff.compute(prev: a, next: b, styles: CellCellStyleTable()), "")
    }

    func testSingleCellChange() {
        let styles = CellCellStyleTable()
        var a = Screen(width: 5, height: 1)
        var b = Screen(width: 5, height: 1)
        b.write(text: "x", at: 2, row: 0, styleId: 0)
        let out = ScreenDiff.compute(prev: a, next: b, styles: styles)
        // Cursor to row=1 col=3 (1-based), reset, write "x"
        XCTAssertTrue(out.contains("\u{1B}[1;3H"))
        XCTAssertTrue(out.hasSuffix("x"))
    }

    func testRowFullRewrite() {
        let styles = CellCellStyleTable()
        var a = Screen(width: 5, height: 1)
        var b = Screen(width: 5, height: 1)
        b.write(text: "hello", at: 0, row: 0, styleId: 0)
        let out = ScreenDiff.compute(prev: a, next: b, styles: styles)
        XCTAssertTrue(out.contains("\u{1B}[1;1H"))
        XCTAssertTrue(out.contains("hello"))
    }

    func testFirstFrameClearsAndPaints() {
        let styles = CellCellStyleTable()
        var b = Screen(width: 5, height: 1)
        b.write(text: "hi", at: 0, row: 0, styleId: 0)
        let out = ScreenDiff.computeInitial(next: b, styles: styles)
        XCTAssertTrue(out.contains("\u{1B}[2J"))
        XCTAssertTrue(out.contains("hi"))
    }
}
```

- [ ] **Step 10: Run, verify fail**

```bash
swift test --filter ScreenDiffTests
```

Expected: FAIL.

- [ ] **Step 11: Implement Screen and ScreenDiff**

`Sources/SwiftCodeTerminalUI/Renderer/Screen.swift`:

```swift
public struct ScreenCell: Equatable, Sendable {
    public var character: Character
    public var width: Int           // 1 for normal, 2 for CJK
    public var styleId: CellStyleTable.StyleID

    public static let blank = ScreenCell(character: " ", width: 1, styleId: 0)
}

public struct Screen: Sendable {
    public let width: Int
    public let height: Int
    public private(set) var cells: [ScreenCell]

    public init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
        self.cells = Array(repeating: .blank, count: self.width * self.height)
    }

    public func cell(at col: Int, row: Int) -> ScreenCell {
        guard col >= 0 && col < width && row >= 0 && row < height else { return .blank }
        return cells[row * width + col]
    }

    public mutating func setCell(_ cell: ScreenCell, at col: Int, row: Int) {
        guard col >= 0 && col < width && row >= 0 && row < height else { return }
        cells[row * width + col] = cell
    }

    public mutating func write(text: String, at col: Int, row: Int, styleId: CellStyleTable.StyleID) {
        var c = col
        for ch in text {
            setCell(ScreenCell(character: ch, width: 1, styleId: styleId), at: c, row: row)
            c += 1
            if c >= width { return }
        }
    }
}

public enum ScreenDiff {
    /// Compute minimal cursor-positioned ANSI updates from prev → next.
    /// Walks row-by-row, finds runs of differing cells, repositions and writes.
    public static func compute(prev: Screen, next: Screen, styles: CellStyleTable) -> String {
        guard prev.width == next.width, prev.height == next.height else {
            return computeInitial(next: next, styles: styles)
        }
        var out = ""
        var currentStyle: CellStyleTable.StyleID = 0
        for row in 0..<next.height {
            var col = 0
            while col < next.width {
                if prev.cell(at: col, row: row) == next.cell(at: col, row: row) {
                    col += 1
                    continue
                }
                // Found a diff; emit cursor positioning
                out += ANSIEscapes.cursorTo(row: row + 1, col: col + 1)
                // Walk run of diffs
                while col < next.width && prev.cell(at: col, row: row) != next.cell(at: col, row: row) {
                    let cell = next.cell(at: col, row: row)
                    if cell.styleId != currentStyle {
                        out += ANSIEscapes.sgrReset
                        out += styles.style(for: cell.styleId).sgrOpen()
                        currentStyle = cell.styleId
                    }
                    out += String(cell.character)
                    col += 1
                }
            }
        }
        if !out.isEmpty {
            out += ANSIEscapes.sgrReset
        }
        return out
    }

    /// First frame: clear screen, paint everything.
    public static func computeInitial(next: Screen, styles: CellStyleTable) -> String {
        var out = ANSIEscapes.clearScreen + ANSIEscapes.cursorTo(row: 1, col: 1)
        var currentStyle: CellStyleTable.StyleID = 0
        for row in 0..<next.height {
            out += ANSIEscapes.cursorTo(row: row + 1, col: 1)
            for col in 0..<next.width {
                let cell = next.cell(at: col, row: row)
                if cell.styleId != currentStyle {
                    out += ANSIEscapes.sgrReset
                    out += styles.style(for: cell.styleId).sgrOpen()
                    currentStyle = cell.styleId
                }
                out += String(cell.character)
            }
        }
        out += ANSIEscapes.sgrReset
        return out
    }
}
```

- [ ] **Step 12: Run, verify pass**

```bash
swift test --filter "ScreenDiffTests|StyleTableTests|AnsiEscapesTests"
```

Expected: PASS.

- [ ] **Step 13: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/Renderer/ANSIEscapes.swift \
        Sources/SwiftCodeTerminalUI/Renderer/StyleTable.swift \
        Sources/SwiftCodeTerminalUI/Renderer/Screen.swift \
        Sources/SwiftCodeTerminalUI/Renderer/ScreenDiff.swift \
        Tests/SwiftCodeTerminalUITests/AnsiEscapesTests.swift \
        Tests/SwiftCodeTerminalUITests/StyleTableTests.swift \
        Tests/SwiftCodeTerminalUITests/ScreenDiffTests.swift
git commit -m "feat(tui): screen buffer + ANSI diff renderer"
```

---

## Task 2: Text Wrap And Width Measurement

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/Renderer/TextWrap.swift`
- Test: `Tests/SwiftCodeTerminalUITests/TextWrapTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/SwiftCodeTerminalUITests/TextWrapTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class TextWrapTests: XCTestCase {
    func testSingleLineFits() {
        XCTAssertEqual(TextWrap.wrap("hello", width: 10), ["hello"])
    }

    func testWrapsAtWord() {
        XCTAssertEqual(TextWrap.wrap("hello world", width: 5), ["hello", "world"])
    }

    func testLongWordSplits() {
        XCTAssertEqual(TextWrap.wrap("abcdefghij", width: 4), ["abcd", "efgh", "ij"])
    }

    func testRespectsExistingNewlines() {
        XCTAssertEqual(TextWrap.wrap("a\nb", width: 10), ["a", "b"])
    }

    func testCellWidthAscii() {
        XCTAssertEqual(TextWrap.cellWidth("hello"), 5)
    }

    func testCellWidthCjk() {
        // CJK character "中" is width 2
        XCTAssertEqual(TextWrap.cellWidth("中"), 2)
        XCTAssertEqual(TextWrap.cellWidth("中文"), 4)
    }

    func testEmptyInputProducesEmptyLine() {
        XCTAssertEqual(TextWrap.wrap("", width: 5), [""])
    }
}
```

- [ ] **Step 2: Run, verify fail**

```bash
swift test --filter TextWrapTests
```

Expected: FAIL.

- [ ] **Step 3: Implement TextWrap**

`Sources/SwiftCodeTerminalUI/Renderer/TextWrap.swift`:

```swift
public enum TextWrap {
    /// Visible cell width of `text`, treating CJK / emoji as width 2.
    public static func cellWidth(_ text: String) -> Int {
        var total = 0
        for scalar in text.unicodeScalars {
            total += scalarWidth(scalar)
        }
        return total
    }

    /// Word-wrap `text` to lines of at most `width` cells. Honors existing newlines.
    public static func wrap(_ text: String, width: Int) -> [String] {
        guard width > 0 else { return [text] }
        if text.isEmpty { return [""] }
        var result: [String] = []
        for paragraph in text.components(separatedBy: "\n") {
            result.append(contentsOf: wrapParagraph(paragraph, width: width))
        }
        return result
    }

    private static func wrapParagraph(_ text: String, width: Int) -> [String] {
        if text.isEmpty { return [""] }
        var lines: [String] = []
        var current = ""
        var currentWidth = 0
        let words = splitWords(text)
        for word in words {
            let w = cellWidth(word)
            if word == " " {
                if currentWidth + 1 <= width {
                    current += " "
                    currentWidth += 1
                }
                continue
            }
            if currentWidth == 0 && w > width {
                // Word longer than line: hard-break
                var remaining = word
                while !remaining.isEmpty {
                    var take = ""
                    var takeWidth = 0
                    for ch in remaining {
                        let cw = cellWidth(String(ch))
                        if takeWidth + cw > width { break }
                        take.append(ch)
                        takeWidth += cw
                    }
                    if take.isEmpty {
                        take = String(remaining.first!)
                    }
                    lines.append(take)
                    remaining = String(remaining.dropFirst(take.count))
                }
                continue
            }
            if currentWidth + w > width {
                lines.append(current.trimmingTrailingSpace())
                current = ""
                currentWidth = 0
            }
            current += word
            currentWidth += w
        }
        if !current.isEmpty || lines.isEmpty {
            lines.append(current.trimmingTrailingSpace())
        }
        return lines
    }

    private static func splitWords(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""
        for ch in text {
            if ch == " " {
                if !current.isEmpty { words.append(current); current = "" }
                words.append(" ")
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    private static func scalarWidth(_ scalar: Unicode.Scalar) -> Int {
        let v = scalar.value
        if v == 0 { return 0 }
        if v < 0x20 || (v >= 0x7F && v < 0xA0) { return 0 }
        // East Asian Wide / Fullwidth ranges (subset, sufficient for CJK + common emoji)
        if (v >= 0x1100 && v <= 0x115F) ||
           (v >= 0x2E80 && v <= 0x303E) ||
           (v >= 0x3041 && v <= 0x33FF) ||
           (v >= 0x3400 && v <= 0x4DBF) ||
           (v >= 0x4E00 && v <= 0x9FFF) ||
           (v >= 0xA000 && v <= 0xA4CF) ||
           (v >= 0xAC00 && v <= 0xD7A3) ||
           (v >= 0xF900 && v <= 0xFAFF) ||
           (v >= 0xFE30 && v <= 0xFE4F) ||
           (v >= 0xFF00 && v <= 0xFF60) ||
           (v >= 0xFFE0 && v <= 0xFFE6) ||
           (v >= 0x1F300 && v <= 0x1F64F) ||
           (v >= 0x1F900 && v <= 0x1F9FF) {
            return 2
        }
        return 1
    }
}

extension String {
    fileprivate func trimmingTrailingSpace() -> String {
        var s = self
        while s.hasSuffix(" ") { s.removeLast() }
        return s
    }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
swift test --filter TextWrapTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/Renderer/TextWrap.swift \
        Tests/SwiftCodeTerminalUITests/TextWrapTests.swift
git commit -m "feat(tui): word-aware text wrap with CJK width"
```

---

## Task 3: Extend Yoga Layout (flexGrow, gap, alignSelf, percentage width)

**Files:**
- Modify: `Sources/SwiftCodeTerminalUI/Yoga/YogaStyle.swift`
- Modify: `Sources/SwiftCodeTerminalUI/Yoga/YogaNode.swift`
- Modify: `Sources/SwiftCodeTerminalUI/Yoga/YogaCalculator.swift`
- Test: `Tests/SwiftCodeTerminalUITests/YogaLayoutTests.swift` *(extend existing)*

- [ ] **Step 1: Read current YogaNode**

```bash
cat Sources/SwiftCodeTerminalUI/Yoga/YogaNode.swift
```

Expected: file exists, has basic `flexDirection`, `width`, `height`, `padding`, `margin`, no `flexGrow` / `gap`.

- [ ] **Step 2: Write failing tests for new layout features**

Add to `Tests/SwiftCodeTerminalUITests/YogaLayoutTests.swift` (create if absent):

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class YogaLayoutTests: XCTestCase {
    func testFlexGrowDistributesFreeSpace() {
        let root = YogaNode()
        root.width = .fixed(20)
        root.height = .fixed(1)
        root.flexDirection = .row
        let a = YogaNode(); a.flexGrow = 1
        let b = YogaNode(); b.flexGrow = 2
        root.addChild(a); root.addChild(b)
        YogaCalculator().calculate(root: root, availableWidth: 20, availableHeight: 1)
        // 20 cells split 1:2 → 7 and 13
        XCTAssertEqual(a.layoutWidth, 7)
        XCTAssertEqual(b.layoutWidth, 13)
        XCTAssertEqual(b.layoutX, 7)
    }

    func testGapColumnDirection() {
        let root = YogaNode()
        root.width = .fixed(10)
        root.height = .auto
        root.flexDirection = .column
        root.gap = 1
        let a = YogaNode(); a.height = .fixed(1)
        let b = YogaNode(); b.height = .fixed(1)
        let c = YogaNode(); c.height = .fixed(1)
        root.addChild(a); root.addChild(b); root.addChild(c)
        YogaCalculator().calculate(root: root, availableWidth: 10, availableHeight: 10)
        XCTAssertEqual(a.layoutY, 0)
        XCTAssertEqual(b.layoutY, 2) // 1 row gap
        XCTAssertEqual(c.layoutY, 4)
    }

    func testAlignSelfEnd() {
        let root = YogaNode()
        root.width = .fixed(20)
        root.height = .fixed(5)
        root.flexDirection = .row
        root.alignItems = .start
        let a = YogaNode(); a.width = .fixed(3); a.height = .fixed(1); a.alignSelf = .end
        root.addChild(a)
        YogaCalculator().calculate(root: root, availableWidth: 20, availableHeight: 5)
        XCTAssertEqual(a.layoutY, 4) // bottom of 5-row row
    }

    func testPercentageWidth() {
        let root = YogaNode()
        root.width = .fixed(20)
        root.flexDirection = .row
        let a = YogaNode(); a.width = .percent(0.5); a.height = .fixed(1)
        root.addChild(a)
        YogaCalculator().calculate(root: root, availableWidth: 20, availableHeight: 1)
        XCTAssertEqual(a.layoutWidth, 10)
    }

    func testDisplayNoneZeroSize() {
        let root = YogaNode()
        root.flexDirection = .column
        root.width = .fixed(10)
        let a = YogaNode(); a.height = .fixed(3)
        let b = YogaNode(); b.height = .fixed(2); b.display = .none
        let c = YogaNode(); c.height = .fixed(4)
        root.addChild(a); root.addChild(b); root.addChild(c)
        YogaCalculator().calculate(root: root, availableWidth: 10, availableHeight: 20)
        XCTAssertEqual(b.layoutWidth, 0)
        XCTAssertEqual(b.layoutHeight, 0)
        XCTAssertEqual(c.layoutY, 3) // immediately after `a`, skipping `b`
    }
}
```

- [ ] **Step 3: Run, verify fail**

```bash
swift test --filter YogaLayoutTests
```

Expected: FAIL on multiple cases (`flexGrow`, `gap`, `alignSelf`, `.percent`, `display`).

- [ ] **Step 4: Extend YogaStyle**

Add to `Sources/SwiftCodeTerminalUI/Yoga/YogaStyle.swift`:

```swift
public enum Display: Sendable {
    case flex
    case none
}

public enum AlignSelf: Sendable {
    case auto
    case start
    case center
    case end
    case stretch
}
```

- [ ] **Step 5: Extend YogaNode**

Modify `Sources/SwiftCodeTerminalUI/Yoga/YogaNode.swift` — add stored properties (with sensible defaults so existing call sites compile):

```swift
public var flexGrow: Double = 0
public var flexShrink: Double = 1
public var gap: Int = 0
public var alignSelf: AlignSelf = .auto
public var display: Display = .flex
```

- [ ] **Step 6: Update YogaCalculator**

In `Sources/SwiftCodeTerminalUI/Yoga/YogaCalculator.swift`:

1. In `measureWidth`/`measureHeight`: if `node.display == .none`, set layoutWidth=layoutHeight=0 and return.
2. In `layoutColumn`/`layoutRow`: after summing intrinsic sizes, compute free space and distribute it to children with `flexGrow > 0` proportionally. Add a cursor increment of `gap` between children.
3. In `layoutColumn`/`layoutRow`: when assigning cross-axis position, prefer `child.alignSelf` over `node.alignItems` when `child.alignSelf != .auto`.
4. In `measureWidth`/`measureHeight`: if `.percent(p)`, resolve against parent's inner width/height (calculator already passes `availableWidth`).
5. Skip `display:none` children when computing parent's auto size.

- [ ] **Step 7: Run, verify pass**

```bash
swift test --filter YogaLayoutTests
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/Yoga Tests/SwiftCodeTerminalUITests/YogaLayoutTests.swift
git commit -m "feat(tui): yoga adds flexGrow, gap, alignSelf, display:none"
```

---

## Task 4: Theme + View Protocol + Box/Text/Spinner Rewrite

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/Theme/Theme.swift`
- Rewrite: `Sources/SwiftCodeTerminalUI/Components/Text.swift`
- Rewrite: `Sources/SwiftCodeTerminalUI/Components/Box.swift`
- Rewrite: `Sources/SwiftCodeTerminalUI/Components/Spinner.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/Newline.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/Spacer.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/View.swift`
- Create: `Sources/SwiftCodeTerminalUI/Renderer/PaintContext.swift`
- Test: `Tests/SwiftCodeTerminalUITests/ViewSnapshotTests.swift`

- [ ] **Step 1: Write failing test for theme tokens**

`Tests/SwiftCodeTerminalUITests/ViewSnapshotTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class ViewSnapshotTests: XCTestCase {
    func testClaudeOrangeTokenIsRgb() {
        let theme = Theme.default
        XCTAssertEqual(theme.claude, .rgb(215, 119, 87))
        XCTAssertEqual(theme.clawdBody, .rgb(215, 119, 87))
        XCTAssertEqual(theme.clawdBackground, .rgb(0, 0, 0))
    }

    func testRenderTextProducesScreenWithText() {
        let view: any View = TextView("hi", color: .default)
        let screen = renderViewToScreen(view, width: 10, height: 1)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "h")
        XCTAssertEqual(screen.cell(at: 1, row: 0).character, "i")
    }

    func testRenderBoxWithBorder() {
        let view: any View = BoxView(border: .rounded, width: .fixed(5), height: .fixed(3),
                                     children: [TextView("X")])
        let screen = renderViewToScreen(view, width: 10, height: 5)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "╭")
        XCTAssertEqual(screen.cell(at: 4, row: 0).character, "╮")
        XCTAssertEqual(screen.cell(at: 0, row: 2).character, "╰")
        XCTAssertEqual(screen.cell(at: 4, row: 2).character, "╯")
        XCTAssertEqual(screen.cell(at: 1, row: 1).character, "X")
    }

    func testRenderSpinnerWithFrame() {
        let view: any View = SpinnerView(frameIndex: 0)
        let screen = renderViewToScreen(view, width: 2, height: 1)
        XCTAssertEqual(String(screen.cell(at: 0, row: 0).character), Spinner.dotsFrames[0])
    }
}
```

(`renderViewToScreen` is a test helper exposed in Step 5; declared on the SUT side as `public func renderViewToScreen(_ view: any View, width: Int, height: Int) -> Screen`.)

- [ ] **Step 2: Run, verify fail**

```bash
swift test --filter ViewSnapshotTests
```

Expected: FAIL — `Theme`, `View`, `TextView`, etc. undefined.

- [ ] **Step 3: Implement Theme**

`Sources/SwiftCodeTerminalUI/Theme/Theme.swift`:

```swift
public struct Theme: Sendable {
    public let claude: CellColor          // brand orange
    public let clawdBody: CellColor       // mascot body
    public let clawdBackground: CellColor // mascot dark bg
    public let text: CellColor
    public let dim: CellColor
    public let permission: CellColor
    public let planMode: CellColor
    public let autoAccept: CellColor
    public let warning: CellColor
    public let error: CellColor
    public let success: CellColor

    public static let `default` = Theme(
        claude: .rgb(215, 119, 87),
        clawdBody: .rgb(215, 119, 87),
        clawdBackground: .rgb(0, 0, 0),
        text: .default,
        dim: .ansi256(245),
        permission: .ansi256(33),
        planMode: .ansi256(99),
        autoAccept: .ansi256(40),
        warning: .ansi256(214),
        error: .ansi256(160),
        success: .ansi256(40)
    )
}
```

- [ ] **Step 4: Implement View protocol + PaintContext + renderer helper**

`Sources/SwiftCodeTerminalUI/Components/View.swift`:

```swift
public protocol View {
    /// Build the layout node tree for this view. Must be a fresh tree each call.
    func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode
}

/// Layout node + paint thunk. Yoga walks the tree for positions, then we call
/// each node's paint closure to write its cells into the screen.
public final class LayoutNode {
    public let yoga: YogaNode
    public let paint: (inout Screen, LayoutNode) -> Void
    public var children: [LayoutNode] = []

    public init(yoga: YogaNode, paint: @escaping (inout Screen, LayoutNode) -> Void) {
        self.yoga = yoga
        self.paint = paint
    }

    public func addChild(_ child: LayoutNode) {
        children.append(child)
        yoga.addChild(child.yoga)
    }
}

/// Walks a finished layout tree and calls each node's paint closure with
/// absolute coordinates already resolved on the yoga node.
public func paint(node: LayoutNode, into screen: inout Screen) {
    node.paint(&screen, node)
    for child in node.children {
        paint(node: child, into: &screen)
    }
}

/// Test helper: build node, lay out, paint, return Screen.
public func renderViewToScreen(_ view: any View, width: Int, height: Int,
                               theme: Theme = .default,
                               styles: CellStyleTable = CellCellStyleTable()) -> Screen {
    let root = view.buildLayoutNode(theme: theme, styles: styles)
    YogaCalculator().calculate(root: root.yoga, availableWidth: width, availableHeight: height)
    var screen = Screen(width: width, height: height)
    paint(node: root, into: &screen)
    return screen
}
```

- [ ] **Step 5: Rewrite Text/Box/Spinner as Views**

Replace `Sources/SwiftCodeTerminalUI/Components/Text.swift`:

```swift
public struct TextView: View {
    public let content: String
    public let color: CellColor
    public let bold: Bool
    public let dim: Bool
    public let italic: Bool
    public let underline: Bool
    public let inverse: Bool

    public init(_ content: String, color: CellColor = .default,
                bold: Bool = false, dim: Bool = false, italic: Bool = false,
                underline: Bool = false, inverse: Bool = false) {
        self.content = content; self.color = color
        self.bold = bold; self.dim = dim; self.italic = italic
        self.underline = underline; self.inverse = inverse
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let yoga = YogaNode()
        yoga.text = content
        // Auto width = max line cell width; auto height = line count
        let lines = content.components(separatedBy: "\n")
        let maxW = lines.map { TextWrap.cellWidth($0) }.max() ?? 0
        yoga.width = .fixed(maxW)
        yoga.height = .fixed(lines.count)
        let style = CellStyle(fg: color, bold: bold, dim: dim, italic: italic,
                              underline: underline, inverse: inverse)
        let styleId = styles.id(for: style)
        return LayoutNode(yoga: yoga) { screen, node in
            let x = node.yoga.layoutX
            let y = node.yoga.layoutY
            let maxW = node.yoga.layoutWidth
            for (i, line) in lines.enumerated() {
                let wrapped = TextWrap.wrap(line, width: maxW)
                for (j, wline) in wrapped.enumerated() {
                    screen.write(text: wline, at: x, row: y + i + j, styleId: styleId)
                }
            }
        }
    }
}
```

Replace `Sources/SwiftCodeTerminalUI/Components/Box.swift`:

```swift
public struct BoxView: View {
    public let border: BorderStyle
    public let borderColor: CellColor
    public let width: Dimension
    public let height: Dimension
    public let padding: EdgeInsets
    public let margin: EdgeInsets
    public let flexDirection: FlexDirection
    public let justifyContent: JustifyContent
    public let alignItems: AlignItems
    public let gap: Int
    public let flexGrow: Double
    public let children: [any View]

    public init(width: Dimension = .auto, height: Dimension = .auto,
                padding: EdgeInsets = .zero, margin: EdgeInsets = .zero,
                border: BorderStyle = .none, borderColor: CellColor = .default,
                flexDirection: FlexDirection = .column,
                justifyContent: JustifyContent = .start,
                alignItems: AlignItems = .start,
                gap: Int = 0, flexGrow: Double = 0,
                children: [any View] = []) {
        self.width = width; self.height = height
        self.padding = padding; self.margin = margin
        self.border = border; self.borderColor = borderColor
        self.flexDirection = flexDirection; self.justifyContent = justifyContent
        self.alignItems = alignItems; self.gap = gap
        self.flexGrow = flexGrow; self.children = children
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let yoga = YogaNode()
        yoga.width = width; yoga.height = height
        yoga.padding = padding; yoga.margin = margin
        let borderInset = border == .none ? 0 : 1
        yoga.padding = EdgeInsets(top: padding.top + borderInset,
                                  right: padding.right + borderInset,
                                  bottom: padding.bottom + borderInset,
                                  left: padding.left + borderInset)
        yoga.margin = margin
        yoga.flexDirection = flexDirection
        yoga.justifyContent = justifyContent
        yoga.alignItems = alignItems
        yoga.gap = gap
        yoga.flexGrow = flexGrow
        let borderStyle = CellStyle(fg: borderColor)
        let borderStyleId = styles.id(for: borderStyle)
        let bs = border
        let node = LayoutNode(yoga: yoga) { screen, node in
            guard bs != .none else { return }
            paintBorder(into: &screen, node: node, style: bs, styleId: borderStyleId)
        }
        for child in children {
            node.addChild(child.buildLayoutNode(theme: theme, styles: styles))
        }
        return node
    }
}

private func paintBorder(into screen: inout Screen, node: LayoutNode,
                         style: BorderStyle, styleId: CellStyleTable.StyleID) {
    let x = node.yoga.layoutX
    let y = node.yoga.layoutY
    let w = node.yoga.layoutWidth
    let h = node.yoga.layoutHeight
    guard w >= 2 && h >= 2 else { return }
    let chars = borderChars(for: style)
    screen.write(text: String(chars.topLeft), at: x, row: y, styleId: styleId)
    screen.write(text: String(repeating: String(chars.horizontal), count: w - 2),
                 at: x + 1, row: y, styleId: styleId)
    screen.write(text: String(chars.topRight), at: x + w - 1, row: y, styleId: styleId)
    screen.write(text: String(chars.bottomLeft), at: x, row: y + h - 1, styleId: styleId)
    screen.write(text: String(repeating: String(chars.horizontal), count: w - 2),
                 at: x + 1, row: y + h - 1, styleId: styleId)
    screen.write(text: String(chars.bottomRight), at: x + w - 1, row: y + h - 1, styleId: styleId)
    for r in (y + 1)..<(y + h - 1) {
        screen.write(text: String(chars.vertical), at: x, row: r, styleId: styleId)
        screen.write(text: String(chars.vertical), at: x + w - 1, row: r, styleId: styleId)
    }
}

private struct BorderChars {
    let topLeft: Character; let topRight: Character
    let bottomLeft: Character; let bottomRight: Character
    let horizontal: Character; let vertical: Character
}

private func borderChars(for style: BorderStyle) -> BorderChars {
    switch style {
    case .none:    return BorderChars(topLeft: " ", topRight: " ", bottomLeft: " ", bottomRight: " ", horizontal: " ", vertical: " ")
    case .single:  return BorderChars(topLeft: "┌", topRight: "┐", bottomLeft: "└", bottomRight: "┘", horizontal: "─", vertical: "│")
    case .double:  return BorderChars(topLeft: "╔", topRight: "╗", bottomLeft: "╚", bottomRight: "╝", horizontal: "═", vertical: "║")
    case .rounded: return BorderChars(topLeft: "╭", topRight: "╮", bottomLeft: "╰", bottomRight: "╯", horizontal: "─", vertical: "│")
    }
}
```

Replace `Sources/SwiftCodeTerminalUI/Components/Spinner.swift`:

```swift
public enum Spinner {
    public static let dotsFrames: [String] = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
}

public struct SpinnerView: View {
    public let frameIndex: Int
    public let color: CellColor

    public init(frameIndex: Int, color: CellColor = .rgb(215, 119, 87)) {
        self.frameIndex = frameIndex; self.color = color
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let frame = Spinner.dotsFrames[frameIndex % Spinner.dotsFrames.count]
        let yoga = YogaNode()
        yoga.text = frame
        yoga.width = .fixed(1); yoga.height = .fixed(1)
        let styleId = styles.id(for: CellStyle(fg: color))
        return LayoutNode(yoga: yoga) { screen, node in
            screen.write(text: frame, at: node.yoga.layoutX, row: node.yoga.layoutY, styleId: styleId)
        }
    }
}
```

Create `Sources/SwiftCodeTerminalUI/Components/Newline.swift`:

```swift
public struct NewlineView: View {
    public init() {}
    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let yoga = YogaNode(); yoga.width = .fixed(0); yoga.height = .fixed(1)
        return LayoutNode(yoga: yoga) { _, _ in }
    }
}
```

Create `Sources/SwiftCodeTerminalUI/Components/Spacer.swift`:

```swift
public struct SpacerView: View {
    public init() {}
    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let yoga = YogaNode(); yoga.flexGrow = 1
        return LayoutNode(yoga: yoga) { _, _ in }
    }
}
```

Delete the old `BoxComponent`/`TextComponent` if they are no longer referenced; otherwise leave them as deprecated stubs and add `@available(*, deprecated)` until callers migrate.

- [ ] **Step 6: Run, verify pass**

```bash
swift test --filter ViewSnapshotTests
```

Expected: PASS. Build the whole package, expect existing tests to still pass.

```bash
swift build
```

If `BoxComponent` callers break, leave deprecated shims that internally use `BoxView`.

- [ ] **Step 7: Commit**

```bash
git add Sources/SwiftCodeTerminalUI Tests/SwiftCodeTerminalUITests/ViewSnapshotTests.swift
git commit -m "feat(tui): View protocol, theme, Box/Text/Spinner rewrite"
```

---

## Task 5: App, EventLoop, AppLifecycle (raw mode + alt screen + frame loop)

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/App/AppLifecycle.swift`
- Create: `Sources/SwiftCodeTerminalUI/App/EventLoop.swift`
- Create: `Sources/SwiftCodeTerminalUI/App/App.swift`
- Test: `Tests/SwiftCodeTerminalUITests/EventLoopTests.swift`

- [ ] **Step 1: Write failing test**

`Tests/SwiftCodeTerminalUITests/EventLoopTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class EventLoopTests: XCTestCase {
    func testRendersInitialFrameThenUpdatesOnInput() async throws {
        // Headless harness: feed events into the queue, capture stdout bytes.
        let harness = HeadlessAppHarness(width: 20, height: 3)
        let app = App(initialState: TestState(text: "hi"),
                      view: { state in TextView(state.text) },
                      update: { event, state in
                          if case .character(let ch) = event {
                              state.text += String(ch)
                          }
                      },
                      io: harness.io,
                      width: 20, height: 3)
        await app.renderInitialFrame()
        XCTAssertTrue(harness.output().contains("hi"))
        await app.dispatch(.character("X"))
        await app.renderFrameIfNeeded()
        XCTAssertTrue(harness.output().contains("hiX"))
    }

    func testResizeEventTriggersReflow() async throws {
        let harness = HeadlessAppHarness(width: 5, height: 1)
        let app = App(initialState: TestState(text: "hello world"),
                      view: { state in TextView(state.text) },
                      update: { _, _ in },
                      io: harness.io,
                      width: 5, height: 1)
        await app.renderInitialFrame()
        XCTAssertTrue(harness.output().contains("hello"))
        await app.dispatch(.resize(width: 20, height: 1))
        await app.renderFrameIfNeeded()
        XCTAssertTrue(harness.output().contains("hello world"))
    }
}

private struct TestState { var text: String }
```

- [ ] **Step 2: Run, verify fail**

```bash
swift test --filter EventLoopTests
```

Expected: FAIL.

- [ ] **Step 3: Implement AppLifecycle**

`Sources/SwiftCodeTerminalUI/App/AppLifecycle.swift`:

```swift
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

public enum AppLifecycle {
    nonisolated(unsafe) private static var originalTermios = termios()
    nonisolated(unsafe) private static var didEnter = false

    /// Save current termios, enter alt screen, raw mode, hide cursor, enable bracketed paste + focus.
    public static func enter() {
        guard !didEnter else { return }
        didEnter = true
        tcgetattr(STDIN_FILENO, &originalTermios)
        var raw = originalTermios
        cfmakeraw(&raw)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        let setup = ANSIEscapes.enterAltScreen + ANSIEscapes.hideCursor
            + ANSIEscapes.enableBracketedPaste + ANSIEscapes.enableFocusEvents
        FileHandle.standardOutput.write(Data(setup.utf8))
    }

    /// Reverse of `enter` — restore termios + tear down ANSI modes.
    public static func leave() {
        guard didEnter else { return }
        didEnter = false
        let teardown = ANSIEscapes.disableFocusEvents + ANSIEscapes.disableBracketedPaste
            + ANSIEscapes.showCursor + ANSIEscapes.exitAltScreen + ANSIEscapes.sgrReset
        FileHandle.standardOutput.write(Data(teardown.utf8))
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
    }

    /// Install SIGINT / SIGTERM / atexit handlers to ensure `leave` runs.
    public static func installSignalHandlers() {
        signal(SIGINT) { _ in AppLifecycle.leave(); exit(130) }
        signal(SIGTERM) { _ in AppLifecycle.leave(); exit(143) }
        atexit { AppLifecycle.leave() }
    }

    /// Current terminal size (cols, rows). Falls back to (80, 24).
    public static func terminalSize() -> (width: Int, height: Int) {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0 {
            return (Int(ws.ws_col), Int(ws.ws_row))
        }
        return (80, 24)
    }
}
```

- [ ] **Step 4: Implement App actor**

`Sources/SwiftCodeTerminalUI/App/App.swift`:

```swift
public protocol AppIO: Sendable {
    func write(_ bytes: String) async
}

public struct FileHandleIO: AppIO {
    public init() {}
    public func write(_ bytes: String) async {
        FileHandle.standardOutput.write(Data(bytes.utf8))
    }
}

public actor App<State: Sendable> {
    private var state: State
    private let viewFn: @Sendable (State) -> any View
    private let updateFn: @Sendable (InputEvent, inout State) -> Void
    private let io: any AppIO
    private var width: Int
    private var height: Int
    private var theme: Theme = .default
    private var styles = CellCellStyleTable()
    private var previousScreen: Screen?
    private var spinnerFrame = 0

    public init(initialState: State,
                view: @escaping @Sendable (State) -> any View,
                update: @escaping @Sendable (InputEvent, inout State) -> Void,
                io: any AppIO,
                width: Int, height: Int) {
        self.state = initialState
        self.viewFn = view
        self.updateFn = update
        self.io = io
        self.width = width
        self.height = height
    }

    public func renderInitialFrame() async {
        let next = renderScreen()
        let out = ScreenDiff.computeInitial(next: next, styles: styles)
        await io.write(out)
        previousScreen = next
    }

    public func renderFrameIfNeeded() async {
        let next = renderScreen()
        if let prev = previousScreen {
            let out = ScreenDiff.compute(prev: prev, next: next, styles: styles)
            if !out.isEmpty { await io.write(out) }
        } else {
            let out = ScreenDiff.computeInitial(next: next, styles: styles)
            await io.write(out)
        }
        previousScreen = next
    }

    public func dispatch(_ event: InputEvent) {
        switch event {
        case .resize(let w, let h):
            self.width = w; self.height = h
            self.previousScreen = nil  // force full repaint
        default:
            updateFn(event, &state)
        }
    }

    public func tickSpinner() { spinnerFrame &+= 1 }
    public func currentSpinnerFrame() -> Int { spinnerFrame }

    private func renderScreen() -> Screen {
        let view = viewFn(state)
        let root = view.buildLayoutNode(theme: theme, styles: styles)
        YogaCalculator().calculate(root: root.yoga, availableWidth: width, availableHeight: height)
        var screen = Screen(width: width, height: height)
        paint(node: root, into: &screen)
        return screen
    }
}
```

Add `case resize(width: Int, height: Int)` to `InputEvent` (in `Events/InputEvent.swift`).

- [ ] **Step 5: Implement EventLoop**

`Sources/SwiftCodeTerminalUI/App/EventLoop.swift`:

```swift
public final class EventLoop {
    private let reader: InputReader
    private var thread: Thread?
    private let onEvent: @Sendable (InputEvent) -> Void

    public init(reader: InputReader = InputReader(),
                onEvent: @escaping @Sendable (InputEvent) -> Void) {
        self.reader = reader
        self.onEvent = onEvent
    }

    public func start() {
        let t = Thread { [reader, onEvent] in
            while !Thread.current.isCancelled {
                if let event = reader.next() {
                    onEvent(event)
                }
            }
        }
        t.qualityOfService = .userInteractive
        t.start()
        self.thread = t
    }

    public func stop() { thread?.cancel() }
}
```

Add headless harness in tests (`HeadlessAppHarness` is a tiny `AppIO` collecting writes into a thread-safe buffer).

- [ ] **Step 6: Run, verify pass**

```bash
swift test --filter EventLoopTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/App Sources/SwiftCodeTerminalUI/Events/InputEvent.swift \
        Tests/SwiftCodeTerminalUITests/EventLoopTests.swift
git commit -m "feat(tui): App actor + AppLifecycle + EventLoop"
```

---

## Task 6: Welcome Banner With Clawd ASCII Art

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/Components/Welcome/clawd-art.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/Welcome/WelcomeBanner.swift`
- Test: `Tests/SwiftCodeTerminalUITests/WelcomeBannerTests.swift`

- [ ] **Step 1: Read source art rows from reference**

```bash
grep -E "  t[0-9]+ = <Text>" .reference/src/components/LogoV2/WelcomeV2.tsx | sed 's/.*<Text>{"\(.*\)"}<\/Text>;/\1/'
```

Expected: produces the exact source rows (with `█`, `░`, etc.) — copy these into `clawd-art.swift` as Swift string literals, preserving the exact order from `WelcomeV2.tsx` lines 107-196 (dark theme branch, since we are dark by default).

- [ ] **Step 2: Write failing test**

`Tests/SwiftCodeTerminalUITests/WelcomeBannerTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class WelcomeBannerTests: XCTestCase {
    func testWelcomeBannerContainsHeader() {
        let view = WelcomeBanner(version: "2.1.88")
        let screen = renderViewToScreen(view, width: 58, height: 20)
        let header = collectRow(screen, row: 0)
        XCTAssertTrue(header.contains("Welcome to Swift Code"))
        XCTAssertTrue(header.contains("v2.1.88"))
    }

    func testWelcomeBannerContainsClawdBody() {
        let view = WelcomeBanner(version: "2.1.88")
        let screen = renderViewToScreen(view, width: 58, height: 20)
        // Body row at relative offset 11 from header has "█████████" near col 6
        let body = (0..<20).map { collectRow(screen, row: $0) }.joined(separator: "\n")
        XCTAssertTrue(body.contains("█████████"))
        XCTAssertTrue(body.contains("██▄█████▄██"))
    }
}

private func collectRow(_ screen: Screen, row: Int) -> String {
    var s = ""
    for c in 0..<screen.width {
        s.append(screen.cell(at: c, row: row).character)
    }
    return s
}
```

- [ ] **Step 3: Run, verify fail**

```bash
swift test --filter WelcomeBannerTests
```

Expected: FAIL.

- [ ] **Step 4: Implement clawd-art.swift**

`Sources/SwiftCodeTerminalUI/Components/Welcome/clawd-art.swift`:

```swift
/// Hardcoded art rows ported verbatim from .reference/src/components/LogoV2/WelcomeV2.tsx
/// dark theme branch (lines 107-196). Each row is exactly one terminal row;
/// inline color regions are represented via `ArtSpan`.
public enum ClawdArt {
    public struct Span: Sendable {
        public let text: String
        public let color: CellColor
        public let dim: Bool
        public let bold: Bool
        public init(_ text: String, color: CellColor = .default,
                    dim: Bool = false, bold: Bool = false) {
            self.text = text; self.color = color; self.dim = dim; self.bold = bold
        }
    }

    /// Width matches reference WELCOME_V2_WIDTH = 58.
    public static let width = 58

    /// Header row: "Welcome to Swift Code v<version>"
    public static func headerSpans(version: String, theme: Theme) -> [Span] {
        [
            Span("Welcome to Swift Code ", color: theme.claude),
            Span("v\(version) ", dim: true),
        ]
    }

    /// Dark theme art rows (theme != Apple_Terminal && theme != light variants).
    /// Each entry is a list of spans rendered left-to-right; spans without
    /// trailing whitespace are padded to `width` by the renderer.
    public static func darkRows(theme: Theme) -> [[Span]] {
        let body = theme.clawdBody
        let _ = theme.clawdBackground
        return [
            // Reference line 116 (t1 dots) → line 192 (t16). Copy verbatim.
            [Span("……………………………………………………………………………………………………………………………………")],
            [Span("                                                          ")],
            [Span("     *                                       █████▓▓░     ")],
            [Span("                                 *         ███▓░     ░░   ")],
            [Span("            ░░░░░░                        ███▓░           ")],
            [Span("    ░░░   ░░░░░░░░░░                      ███▓░           ")],
            [Span("   ░░░░░░░░░░░░░░░░░░░    ", color: .default), Span("*", bold: true),
             Span("                ██▓░░      ▓   ")],
            [Span("                                             ░▓▓███▓▓░    ")],
            [Span(" *                                 ░░░░                   ", dim: true)],
            [Span("                                 ░░░░░░░░                 ", dim: true)],
            [Span("                               ░░░░░░░░░░░░░░░░           ", dim: true)],
            [Span("      "), Span(" █████████ ", color: body),
             Span("                                       "),
             Span("*", dim: true), Span(" ")],
            [Span("      "), Span("██▄█████▄██", color: body),
             Span("                        "),
             Span("*", bold: true),
             Span("                ")],
            [Span("      "), Span(" █████████ ", color: body),
             Span("     *                                   ")],
            [Span("……………………………"), Span("█ █   █ █", color: body),
             Span("……………………………………………………………………………………")],
        ]
    }
}
```

(The art rows above mirror the dark-theme literal blocks at lines 117-194 of `WelcomeV2.tsx`. Use exact characters from the reference file.)

- [ ] **Step 5: Implement WelcomeBanner view**

`Sources/SwiftCodeTerminalUI/Components/Welcome/WelcomeBanner.swift`:

```swift
public struct WelcomeBanner: View {
    public let version: String

    public init(version: String) { self.version = version }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        var children: [any View] = []
        // Header
        let headerSpans = ClawdArt.headerSpans(version: version, theme: theme)
        children.append(spansRow(headerSpans))
        // Art rows
        for row in ClawdArt.darkRows(theme: theme) {
            children.append(spansRow(row))
        }
        let box = BoxView(width: .fixed(ClawdArt.width),
                          flexDirection: .column,
                          children: children)
        return box.buildLayoutNode(theme: theme, styles: styles)
    }

    private func spansRow(_ spans: [ClawdArt.Span]) -> BoxView {
        let children: [any View] = spans.map { span in
            TextView(span.text, color: span.color, bold: span.bold, dim: span.dim)
        }
        return BoxView(width: .fixed(ClawdArt.width),
                       height: .fixed(1),
                       flexDirection: .row,
                       children: children)
    }
}
```

- [ ] **Step 6: Run, verify pass**

```bash
swift test --filter WelcomeBannerTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/Components/Welcome \
        Tests/SwiftCodeTerminalUITests/WelcomeBannerTests.swift
git commit -m "feat(tui): WelcomeBanner with Clawd ASCII art"
```

---

## Task 7: PromptInput (cursor model + bordered editor + footer)

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/Components/PromptInput/Cursor.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/PromptInput/PromptInput.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/PromptInput/PromptInputFooter.swift`
- Test: `Tests/SwiftCodeTerminalUITests/PromptInputTests.swift`

- [ ] **Step 1: Write failing tests for Cursor**

`Tests/SwiftCodeTerminalUITests/PromptInputTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class PromptInputTests: XCTestCase {
    func testInsertAtCursor() {
        var c = TextCursor(text: "hello", offset: 5)
        c.insert("!")
        XCTAssertEqual(c.text, "hello!")
        XCTAssertEqual(c.offset, 6)
    }

    func testBackspace() {
        var c = TextCursor(text: "hello", offset: 5)
        c.backspace()
        XCTAssertEqual(c.text, "hell")
        XCTAssertEqual(c.offset, 4)
    }

    func testMoveLeftRight() {
        var c = TextCursor(text: "abc", offset: 3)
        c.moveLeft()
        XCTAssertEqual(c.offset, 2)
        c.moveRight()
        XCTAssertEqual(c.offset, 3)
        c.moveRight()  // clamped
        XCTAssertEqual(c.offset, 3)
    }

    func testRenderPromptInputBoxWithPlaceholder() {
        let view = PromptInput(cursor: TextCursor(text: "", offset: 0),
                               placeholder: "Try \"how does X work?\"",
                               width: 40)
        let screen = renderViewToScreen(view, width: 40, height: 3)
        // Rounded border
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "╭")
        XCTAssertEqual(screen.cell(at: 39, row: 0).character, "╮")
        // ">" prompt marker on row 1, col 2
        XCTAssertEqual(screen.cell(at: 2, row: 1).character, ">")
    }

    func testRenderPromptInputBoxWithTypedText() {
        let view = PromptInput(cursor: TextCursor(text: "hello", offset: 5),
                               placeholder: "...",
                               width: 40)
        let screen = renderViewToScreen(view, width: 40, height: 3)
        // typed text after "> "
        XCTAssertEqual(screen.cell(at: 4, row: 1).character, "h")
        XCTAssertEqual(screen.cell(at: 5, row: 1).character, "e")
        XCTAssertEqual(screen.cell(at: 8, row: 1).character, "o")
    }
}
```

- [ ] **Step 2: Run, verify fail**

```bash
swift test --filter PromptInputTests
```

Expected: FAIL.

- [ ] **Step 3: Implement TextCursor**

`Sources/SwiftCodeTerminalUI/Components/PromptInput/Cursor.swift`:

```swift
public struct TextCursor: Sendable, Equatable {
    public var text: String
    public var offset: Int

    public init(text: String = "", offset: Int = 0) {
        self.text = text; self.offset = max(0, min(text.count, offset))
    }

    public mutating func insert(_ s: String) {
        let idx = text.index(text.startIndex, offsetBy: offset)
        text.insert(contentsOf: s, at: idx)
        offset += s.count
    }

    public mutating func backspace() {
        guard offset > 0 else { return }
        let prev = text.index(text.startIndex, offsetBy: offset - 1)
        text.remove(at: prev)
        offset -= 1
    }

    public mutating func delete() {
        guard offset < text.count else { return }
        let idx = text.index(text.startIndex, offsetBy: offset)
        text.remove(at: idx)
    }

    public mutating func moveLeft() { offset = max(0, offset - 1) }
    public mutating func moveRight() { offset = min(text.count, offset + 1) }
    public mutating func moveHome() { offset = 0 }
    public mutating func moveEnd() { offset = text.count }
}
```

- [ ] **Step 4: Implement PromptInput view**

`Sources/SwiftCodeTerminalUI/Components/PromptInput/PromptInput.swift`:

```swift
public struct PromptInput: View {
    public let cursor: TextCursor
    public let placeholder: String
    public let width: Int

    public init(cursor: TextCursor, placeholder: String = "", width: Int) {
        self.cursor = cursor; self.placeholder = placeholder; self.width = width
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let isEmpty = cursor.text.isEmpty
        let displayText = isEmpty ? placeholder : cursor.text
        let row = BoxView(width: .auto, height: .fixed(1), flexDirection: .row, children: [
            TextView("> ", color: theme.text),
            TextView(displayText, dim: isEmpty),
        ])
        let box = BoxView(width: .fixed(width),
                          padding: EdgeInsets(horizontal: 1),
                          border: .rounded,
                          borderColor: .ansi256(240),
                          flexDirection: .column,
                          children: [row])
        return box.buildLayoutNode(theme: theme, styles: styles)
    }
}
```

- [ ] **Step 5: Run, verify pass**

```bash
swift test --filter PromptInputTests
```

Expected: PASS.

- [ ] **Step 6: Implement footer**

`Sources/SwiftCodeTerminalUI/Components/PromptInput/PromptInputFooter.swift`:

```swift
public struct PromptInputFooter: View {
    public let modeLabel: String?      // e.g. "Plan Mode" or nil
    public let modeColor: CellColor    // theme.planMode / theme.autoAccept / nil
    public let shortcuts: [String]     // ["⏎ send", "? help", "esc clear"]
    public let cwd: String?

    public init(modeLabel: String? = nil, modeColor: CellColor = .default,
                shortcuts: [String] = [], cwd: String? = nil) {
        self.modeLabel = modeLabel; self.modeColor = modeColor
        self.shortcuts = shortcuts; self.cwd = cwd
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        var children: [any View] = []
        if let label = modeLabel {
            children.append(TextView("⏵⏵ \(label) ", color: modeColor))
        }
        if let cwd = cwd {
            children.append(TextView(cwd, dim: true))
        }
        children.append(SpacerView())
        if !shortcuts.isEmpty {
            children.append(TextView(shortcuts.joined(separator: "  "), dim: true))
        }
        return BoxView(width: .auto, height: .fixed(1),
                       flexDirection: .row,
                       children: children).buildLayoutNode(theme: theme, styles: styles)
    }
}
```

- [ ] **Step 7: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/Components/PromptInput \
        Tests/SwiftCodeTerminalUITests/PromptInputTests.swift
git commit -m "feat(tui): PromptInput with cursor model, border, footer"
```

---

## Task 8: Message Renderers (User, Assistant, System)

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/Components/Messages/UserMessage.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/Messages/AssistantMessage.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/Messages/SystemMessage.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/Messages/MessageList.swift`
- Test: `Tests/SwiftCodeTerminalUITests/MessageRenderingTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/SwiftCodeTerminalUITests/MessageRenderingTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class MessageRenderingTests: XCTestCase {
    func testUserMessageHasGreaterThanMarker() {
        let view = UserMessageView(text: "hello")
        let screen = renderViewToScreen(view, width: 20, height: 1)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, ">")
        XCTAssertEqual(screen.cell(at: 2, row: 0).character, "h")
    }

    func testAssistantMessageHasBulletMarker() {
        let view = AssistantMessageView(text: "hi there")
        let screen = renderViewToScreen(view, width: 20, height: 1)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "●")
    }

    func testAssistantMessageWrapsLongText() {
        let view = AssistantMessageView(text: "this is a longer message that should wrap to multiple lines")
        let screen = renderViewToScreen(view, width: 20, height: 5)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "●")
        // continuation lines indent by 2 (no bullet)
        XCTAssertEqual(screen.cell(at: 0, row: 1).character, " ")
        XCTAssertEqual(screen.cell(at: 1, row: 1).character, " ")
    }

    func testMessageListRendersInOrder() {
        let messages: [any View] = [
            UserMessageView(text: "first"),
            AssistantMessageView(text: "second"),
        ]
        let view = MessageList(messages: messages)
        let screen = renderViewToScreen(view, width: 20, height: 4)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, ">")
        XCTAssertEqual(screen.cell(at: 0, row: 2).character, "●")
    }
}
```

- [ ] **Step 2: Run, verify fail**

```bash
swift test --filter MessageRenderingTests
```

Expected: FAIL.

- [ ] **Step 3: Implement message views**

`Sources/SwiftCodeTerminalUI/Components/Messages/UserMessage.swift`:

```swift
public struct UserMessageView: View {
    public let text: String
    public init(text: String) { self.text = text }
    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        BoxView(width: .auto, flexDirection: .row, children: [
            TextView("> ", dim: true),
            TextView(text),
        ]).buildLayoutNode(theme: theme, styles: styles)
    }
}
```

`Sources/SwiftCodeTerminalUI/Components/Messages/AssistantMessage.swift`:

```swift
public struct AssistantMessageView: View {
    public let text: String
    public init(text: String) { self.text = text }
    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        // Bullet on first line, two-space indent on subsequent lines.
        // We render as a column of text rows, wrapping at parent width.
        let bullet = TextView("● ", color: theme.claude)
        let body = WrappedTextView(text: text, indent: 2)
        return BoxView(width: .auto, flexDirection: .row, children: [bullet, body])
            .buildLayoutNode(theme: theme, styles: styles)
    }
}

/// Helper view: wraps long text against parent's available width, with hanging indent on lines 2+.
public struct WrappedTextView: View {
    public let text: String
    public let indent: Int
    public init(text: String, indent: Int = 0) { self.text = text; self.indent = indent }
    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        let yoga = YogaNode()
        yoga.width = .auto
        yoga.flexGrow = 1
        let textCopy = text
        let indentCopy = indent
        let styleId = styles.id(for: CellStyle())
        return LayoutNode(yoga: yoga) { screen, node in
            let availW = max(1, node.yoga.layoutWidth)
            let lines = TextWrap.wrap(textCopy, width: availW)
            for (i, line) in lines.enumerated() {
                let prefix = i == 0 ? "" : String(repeating: " ", count: indentCopy)
                screen.write(text: prefix + line,
                             at: node.yoga.layoutX, row: node.yoga.layoutY + i,
                             styleId: styleId)
            }
            // Mutate height to actual rendered line count so siblings/parents reflow.
            // (single-pass paint after layout; parent already accounted via flexGrow.)
            // Best-effort: stretch yoga to line count via setting layoutHeight.
            node.yoga.layoutHeight = lines.count
        }
    }
}
```

(`WrappedTextView` has a known limitation: height is computed during paint, so parent layout assumes single-row. Acceptable trade-off for v1; a future task can add a measure phase.)

`Sources/SwiftCodeTerminalUI/Components/Messages/SystemMessage.swift`:

```swift
public struct SystemMessageView: View {
    public let text: String
    public init(text: String) { self.text = text }
    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        TextView("  \(text)", dim: true, italic: true)
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
```

`Sources/SwiftCodeTerminalUI/Components/Messages/MessageList.swift`:

```swift
public struct MessageList: View {
    public let messages: [any View]
    public init(messages: [any View]) { self.messages = messages }
    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        // Insert a blank row between messages.
        var children: [any View] = []
        for (i, m) in messages.enumerated() {
            if i > 0 { children.append(NewlineView()) }
            children.append(m)
        }
        return BoxView(width: .auto, flexDirection: .column, children: children)
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
swift test --filter MessageRenderingTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/Components/Messages \
        Tests/SwiftCodeTerminalUITests/MessageRenderingTests.swift
git commit -m "feat(tui): user/assistant/system message renderers"
```

---

## Task 9: ChatScreen + Rewrite InteractiveREPL To Use The TUI

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/ChatScreen.swift`
- Rewrite: `Sources/SwiftCodeCLI/InteractiveREPL.swift`
- Test: `Tests/SwiftCodeTerminalUITests/ChatScreenTests.swift`
- Modify: `Package.swift` to make `SwiftCodeCLI` depend on `SwiftCodeTerminalUI` (verify it already does — `Sources/SwiftCodeCLI/Bootstrap.swift` etc. probably already pull it in)

- [ ] **Step 1: Check Package.swift dependency**

```bash
grep -A 1 "SwiftCodeCLI" Package.swift
```

Expected: `SwiftCodeCLI` depends on `SwiftCodeTerminalUI`. If not, add it.

- [ ] **Step 2: Write failing ChatScreen test**

`Tests/SwiftCodeTerminalUITests/ChatScreenTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class ChatScreenTests: XCTestCase {
    func testEmptyChatShowsWelcomeAndPrompt() {
        let view = ChatScreen(
            state: ChatScreenState(
                version: "2.1.88",
                messages: [],
                cursor: TextCursor(),
                isLoading: false,
                spinnerFrame: 0,
                modeLabel: nil
            )
        )
        let screen = renderViewToScreen(view, width: 80, height: 30)
        let allText = (0..<30).map { row -> String in
            (0..<80).map { String(screen.cell(at: $0, row: row).character) }.joined()
        }.joined(separator: "\n")
        XCTAssertTrue(allText.contains("Welcome to Swift Code"))
        XCTAssertTrue(allText.contains("╭"))   // bordered prompt
        XCTAssertTrue(allText.contains("> "))  // prompt marker
    }

    func testChatWithOneAssistantMessageRendersSpinnerHidden() {
        let view = ChatScreen(
            state: ChatScreenState(
                version: "2.1.88",
                messages: [.assistant("hi from claude")],
                cursor: TextCursor(),
                isLoading: false,
                spinnerFrame: 0,
                modeLabel: nil
            )
        )
        let screen = renderViewToScreen(view, width: 80, height: 30)
        let allText = (0..<30).map { row -> String in
            (0..<80).map { String(screen.cell(at: $0, row: row).character) }.joined()
        }.joined(separator: "\n")
        XCTAssertTrue(allText.contains("● hi from claude"))
        XCTAssertFalse(allText.contains("⠋"))  // no spinner when not loading
    }

    func testChatLoadingShowsSpinner() {
        let view = ChatScreen(
            state: ChatScreenState(
                version: "2.1.88",
                messages: [.user("test")],
                cursor: TextCursor(),
                isLoading: true,
                spinnerFrame: 0,
                modeLabel: nil
            )
        )
        let screen = renderViewToScreen(view, width: 80, height: 30)
        let allText = (0..<30).map { row -> String in
            (0..<80).map { String(screen.cell(at: $0, row: row).character) }.joined()
        }.joined(separator: "\n")
        XCTAssertTrue(allText.contains(Spinner.dotsFrames[0]))
    }
}
```

- [ ] **Step 3: Run, verify fail**

```bash
swift test --filter ChatScreenTests
```

Expected: FAIL.

- [ ] **Step 4: Implement ChatScreen**

`Sources/SwiftCodeTerminalUI/ChatScreen.swift`:

```swift
public enum ChatMessage: Sendable, Equatable {
    case user(String)
    case assistant(String)
    case system(String)
}

public struct ChatScreenState: Sendable, Equatable {
    public var version: String
    public var messages: [ChatMessage]
    public var cursor: TextCursor
    public var isLoading: Bool
    public var spinnerFrame: Int
    public var modeLabel: String?
    public var cwd: String?

    public init(version: String, messages: [ChatMessage] = [],
                cursor: TextCursor = TextCursor(), isLoading: Bool = false,
                spinnerFrame: Int = 0, modeLabel: String? = nil,
                cwd: String? = nil) {
        self.version = version; self.messages = messages
        self.cursor = cursor; self.isLoading = isLoading
        self.spinnerFrame = spinnerFrame; self.modeLabel = modeLabel
        self.cwd = cwd
    }
}

public struct ChatScreen: View {
    public let state: ChatScreenState
    public init(state: ChatScreenState) { self.state = state }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        var rows: [any View] = []
        if state.messages.isEmpty {
            rows.append(WelcomeBanner(version: state.version))
        } else {
            let msgs: [any View] = state.messages.map { msg in
                switch msg {
                case .user(let t):       return UserMessageView(text: t) as any View
                case .assistant(let t):  return AssistantMessageView(text: t) as any View
                case .system(let t):     return SystemMessageView(text: t) as any View
                }
            }
            rows.append(MessageList(messages: msgs))
        }
        rows.append(NewlineView())
        if state.isLoading {
            rows.append(BoxView(width: .auto, flexDirection: .row, children: [
                SpinnerView(frameIndex: state.spinnerFrame, color: theme.claude),
                TextView(" thinking…", dim: true),
            ]))
            rows.append(NewlineView())
        }
        // Prompt input + footer pinned to bottom-ish via flex-grow spacer above
        rows.insert(SpacerView(), at: rows.count) // spacer pushes input down only when room
        rows.append(PromptInput(cursor: state.cursor,
                                placeholder: "Try \"how does this work?\"",
                                width: max(20, /* width passed by parent */ 80)))
        rows.append(PromptInputFooter(
            modeLabel: state.modeLabel,
            modeColor: theme.autoAccept,
            shortcuts: ["⏎ send", "? help", "ctrl+c exit"],
            cwd: state.cwd
        ))
        return BoxView(width: .auto, height: .auto,
                       flexDirection: .column, children: rows)
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
```

(`PromptInput` taking a fixed width is a wart; once `WrappedTextView`-style content-flex is solid, switch to `.auto` flex.)

- [ ] **Step 5: Run, verify pass**

```bash
swift test --filter ChatScreenTests
```

Expected: PASS.

- [ ] **Step 6: Rewrite InteractiveREPL**

Replace `Sources/SwiftCodeCLI/InteractiveREPL.swift` so its `run()` method:

1. Installs `AppLifecycle.installSignalHandlers()`.
2. Calls `AppLifecycle.enter()`.
3. Reads `terminalSize()`.
4. Constructs an `App<ChatScreenState>` with view = `{ ChatScreen(state: $0) }`.
5. Update function dispatches `InputEvent` cases:
   - `.character(c)` → `state.cursor.insert(String(c))`
   - `.backspace` → `state.cursor.backspace()`
   - `.delete` → `state.cursor.delete()`
   - `.arrowLeft/.arrowRight` → cursor moves
   - `.return` (or `.character("\n")` per InputReader behaviour) → submit: append `.user(state.cursor.text)`, clear cursor, kick off async query, set `isLoading=true`.
   - `.controlChar("c")` → exit
   - `.paste(s)` → `state.cursor.insert(s)`
6. Starts `EventLoop` that funnels events into a `Task { await app.dispatch(event); await app.renderFrameIfNeeded() }`.
7. Background async task: every 80ms while `isLoading`, dispatch `.timer` to tick the spinner frame and re-render.
8. On exit (Ctrl-C, /exit), calls `AppLifecycle.leave()` and returns.
9. When the assistant message arrives, append `.assistant(text)`, set `isLoading=false`, re-render.

Implementation outline (concrete code in the next step):

- [ ] **Step 7: Concrete InteractiveREPL implementation**

```swift
import Foundation
import SwiftCodeCore
import SwiftCodeAPI
import SwiftCodeAgent
import SwiftCodeCommands
import SwiftCodeTerminalUI

public enum REPLError: Error, Sendable {
    case exitRequested(Int32)
}

public actor InteractiveREPL {
    private let client: any AnthropicAPI
    private let registry: CommandRegistry
    private let model: String
    private let systemPrompt: String?
    private var conversationHistory: [Message] = []

    public init(client: any AnthropicAPI,
                registry: CommandRegistry? = nil,
                model: String = "claude-opus-4-6",
                systemPrompt: String? = nil) {
        self.client = client
        self.registry = registry ?? CommandRegistry.defaultRegistry()
        self.model = model
        self.systemPrompt = systemPrompt
    }

    public func run() async -> Int32 {
        AppLifecycle.installSignalHandlers()
        AppLifecycle.enter()
        defer { AppLifecycle.leave() }

        let size = AppLifecycle.terminalSize()
        let initial = ChatScreenState(
            version: SwiftCodeVersion.value,
            cursor: TextCursor(),
            cwd: FileManager.default.currentDirectoryPath
        )

        let stateBox = StateBox(initial)
        let app = App<ChatScreenState>(
            initialState: initial,
            view: { state in ChatScreen(state: state) },
            update: { event, state in REPLReducer.apply(event: event, to: &state) },
            io: FileHandleIO(),
            width: size.width, height: size.height
        )
        await app.renderInitialFrame()

        // Exit signal channel
        let exitChannel = AsyncStream<Int32>.makeStream()

        let loop = EventLoop(onEvent: { event in
            Task {
                await app.dispatch(event)
                if case .controlChar("c") = event {
                    exitChannel.continuation.yield(0)
                    return
                }
                if case .character(c) = event, c == "\n" {
                    // submit: snapshot text, clear cursor, fire off query
                    let current = await app.currentText()
                    if current.hasPrefix("/exit") {
                        exitChannel.continuation.yield(0); return
                    }
                    if !current.isEmpty {
                        await app.beginLoading()
                        Task { await self.dispatchQuery(text: current, app: app) }
                    }
                }
                await app.renderFrameIfNeeded()
            }
        })
        loop.start()

        // spinner ticker
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 80_000_000)
                await app.tickSpinner()
                await app.renderFrameIfNeeded()
            }
        }

        for await code in exitChannel.stream {
            loop.stop()
            return code
        }
        return 0
    }

    private func dispatchQuery(text: String, app: App<ChatScreenState>) async {
        let engine = QueryEngine(client: client, model: model)
        let userMsg = UserMessage(uuid: UUID().uuidString, content: .text(text), isMeta: false)
        conversationHistory.append(.user(userMsg))
        do {
            let response = try await engine.run(messages: conversationHistory,
                                                systemPrompt: systemPrompt)
            conversationHistory.append(.assistant(response))
            let text = response.content.compactMap { block -> String? in
                if case .text(let t) = block { return t }
                return nil
            }.joined()
            await app.appendAssistant(text)
        } catch {
            await app.appendSystem("Error: \(error)")
            conversationHistory.removeLast()
        }
        await app.endLoading()
        await app.renderFrameIfNeeded()
    }
}

// Helpers on App for REPL state mutation; add these in App.swift in Task 5 if missed.
extension App where State == ChatScreenState {
    public func currentText() -> String { return /* state.cursor.text */ "" }
    public func beginLoading() { /* state.isLoading = true; ... */ }
    public func endLoading() { /* state.isLoading = false */ }
    public func appendAssistant(_ text: String) { /* state.messages.append(.assistant(text)) */ }
    public func appendSystem(_ text: String) { /* state.messages.append(.system(text)) */ }
}
```

(The `App` extension stubs are illustrative — the implementer should wire these by exposing a mutating `withState` helper on `App` and reusing it for both reducer and external mutations. Concrete code mirrors `dispatch` but takes a mutating closure.)

Add to `App.swift`:

```swift
public func withState(_ body: @Sendable (inout State) -> Void) {
    body(&state)
}
```

Then in the extension:

```swift
extension App where State == ChatScreenState {
    public func currentText() -> String {
        var out = ""
        withState { out = $0.cursor.text }
        return out
    }
    public func beginLoading() { withState { $0.isLoading = true; $0.cursor = TextCursor() } }
    public func endLoading() { withState { $0.isLoading = false } }
    public func appendAssistant(_ text: String) { withState { $0.messages.append(.assistant(text)) } }
    public func appendSystem(_ text: String) { withState { $0.messages.append(.system(text)) } }
}
```

Add `REPLReducer` to `Sources/SwiftCodeTerminalUI/App/REPLReducer.swift`:

```swift
public enum REPLReducer {
    public static func apply(event: InputEvent, to state: inout ChatScreenState) {
        switch event {
        case .character(let c):
            if c == "\n" {
                // submit handled by caller; clear handled by App.beginLoading
                return
            }
            state.cursor.insert(String(c))
        case .backspace: state.cursor.backspace()
        case .delete: state.cursor.delete()
        case .arrowLeft: state.cursor.moveLeft()
        case .arrowRight: state.cursor.moveRight()
        case .paste(let s): state.cursor.insert(s)
        default: break
        }
    }
}
```

- [ ] **Step 8: Build, verify**

```bash
swift build
```

Expected: builds successfully. Any unresolved imports get added now.

- [ ] **Step 9: Run interactive smoke test**

```bash
echo "exit" | swift run swiftcode --help | head -5
```

Confirm `--help` still works (non-TTY path: print mode). Then on a TTY, run `dist/swiftcode` (after `swift build -c release && cp .build/release/swiftcode dist/`) and verify the welcome screen + bordered prompt appear, you can type, and Ctrl-C exits cleanly without leaving the terminal in a broken state.

- [ ] **Step 10: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/ChatScreen.swift \
        Sources/SwiftCodeTerminalUI/App/REPLReducer.swift \
        Sources/SwiftCodeTerminalUI/App/App.swift \
        Sources/SwiftCodeCLI/InteractiveREPL.swift \
        Tests/SwiftCodeTerminalUITests/ChatScreenTests.swift \
        Package.swift
git commit -m "feat(tui): ChatScreen + InteractiveREPL rewrite using TUI"
```

---

## Task 10: Confirm + PermissionRequest Dialogs

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/Components/Dialogs/Confirm.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/Dialogs/PermissionRequest.swift`
- Test: `Tests/SwiftCodeTerminalUITests/DialogTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class DialogTests: XCTestCase {
    func testConfirmDialogShowsTitleAndOptions() {
        let view = ConfirmDialog(title: "Delete file?",
                                 detail: "/path/to/file.txt",
                                 yesLabel: "Yes",
                                 noLabel: "No",
                                 selected: .yes)
        let screen = renderViewToScreen(view, width: 60, height: 8)
        let allText = (0..<8).map { row -> String in
            (0..<60).map { String(screen.cell(at: $0, row: row).character) }.joined()
        }.joined(separator: "\n")
        XCTAssertTrue(allText.contains("Delete file?"))
        XCTAssertTrue(allText.contains("/path/to/file.txt"))
        XCTAssertTrue(allText.contains("> Yes"))
        XCTAssertTrue(allText.contains("  No"))
    }

    func testPermissionRequestRendersToolNameAndArgs() {
        let view = PermissionRequestDialog(
            toolName: "Bash",
            description: "rm -rf foo/",
            options: [.allow, .allowAlways, .deny]
        )
        let screen = renderViewToScreen(view, width: 60, height: 10)
        let allText = (0..<10).map { row -> String in
            (0..<60).map { String(screen.cell(at: $0, row: row).character) }.joined()
        }.joined(separator: "\n")
        XCTAssertTrue(allText.contains("Bash"))
        XCTAssertTrue(allText.contains("rm -rf foo/"))
        XCTAssertTrue(allText.contains("Allow"))
        XCTAssertTrue(allText.contains("Allow always"))
        XCTAssertTrue(allText.contains("Deny"))
    }
}
```

- [ ] **Step 2: Run, verify fail**

```bash
swift test --filter DialogTests
```

Expected: FAIL.

- [ ] **Step 3: Implement dialogs**

`Sources/SwiftCodeTerminalUI/Components/Dialogs/Confirm.swift`:

```swift
public struct ConfirmDialog: View {
    public enum Selection: Sendable { case yes, no }
    public let title: String
    public let detail: String?
    public let yesLabel: String
    public let noLabel: String
    public let selected: Selection

    public init(title: String, detail: String? = nil,
                yesLabel: String = "Yes", noLabel: String = "No",
                selected: Selection = .no) {
        self.title = title; self.detail = detail
        self.yesLabel = yesLabel; self.noLabel = noLabel; self.selected = selected
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        var rows: [any View] = [
            TextView(title, bold: true),
        ]
        if let d = detail { rows.append(TextView(d, dim: true)) }
        rows.append(NewlineView())
        rows.append(BoxView(width: .auto, flexDirection: .row, children: [
            TextView(selected == .yes ? "> " : "  "),
            TextView(yesLabel, color: selected == .yes ? theme.claude : .default),
            TextView("   "),
            TextView(selected == .no ? "> " : "  "),
            TextView(noLabel, color: selected == .no ? theme.claude : .default),
        ]))
        return BoxView(width: .auto, padding: EdgeInsets(all: 1),
                       border: .rounded, borderColor: theme.warning,
                       flexDirection: .column, children: rows)
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
```

`Sources/SwiftCodeTerminalUI/Components/Dialogs/PermissionRequest.swift`:

```swift
public struct PermissionRequestDialog: View {
    public enum Option: String, Sendable {
        case allow = "Allow"
        case allowAlways = "Allow always"
        case deny = "Deny"
    }
    public let toolName: String
    public let description: String
    public let options: [Option]
    public let selectedIndex: Int

    public init(toolName: String, description: String,
                options: [Option] = [.allow, .allowAlways, .deny],
                selectedIndex: Int = 0) {
        self.toolName = toolName; self.description = description
        self.options = options; self.selectedIndex = selectedIndex
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        var rows: [any View] = [
            BoxView(width: .auto, flexDirection: .row, children: [
                TextView("● ", color: theme.permission),
                TextView("Tool permission requested", bold: true),
            ]),
            TextView("  \(toolName)", color: theme.claude),
            TextView("  \(description)", dim: true),
            NewlineView(),
        ]
        for (i, opt) in options.enumerated() {
            rows.append(BoxView(width: .auto, flexDirection: .row, children: [
                TextView(i == selectedIndex ? "> " : "  "),
                TextView(opt.rawValue, color: i == selectedIndex ? theme.claude : .default),
            ]))
        }
        return BoxView(width: .auto, padding: EdgeInsets(all: 1),
                       border: .rounded, borderColor: theme.permission,
                       flexDirection: .column, children: rows)
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
```

- [ ] **Step 4: Run, verify pass**

```bash
swift test --filter DialogTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/Components/Dialogs \
        Tests/SwiftCodeTerminalUITests/DialogTests.swift
git commit -m "feat(tui): Confirm + PermissionRequest dialogs"
```

---

## Task 11: UI Parity Contract Document + Smoke Verification

**Files:**
- Create: `docs/parity/ui-contract.md`
- Update: `docs/parity/final-report.md` (append a TUI section)

- [ ] **Step 1: Write UI contract**

`docs/parity/ui-contract.md`:

```markdown
# Terminal UI Parity Contract

## Goal

The Swift implementation of the terminal UI should produce visually
equivalent output to `.reference` Claude Code for the common interactive paths.

## Components shipped (this iteration)

| Component | Status | Snapshot test |
|-----------|--------|---------------|
| Welcome banner (dark theme Clawd) | shipped | WelcomeBannerTests |
| PromptInput (rounded border, cursor, placeholder) | shipped | PromptInputTests |
| PromptInputFooter (mode + shortcuts + cwd) | shipped | PromptInputTests |
| UserMessage (`>` marker) | shipped | MessageRenderingTests |
| AssistantMessage (`●` marker, word wrap) | shipped | MessageRenderingTests |
| SystemMessage (dim italic) | shipped | MessageRenderingTests |
| Spinner (dots frames, animated 80ms) | shipped | ViewSnapshotTests / ChatScreenTests |
| ConfirmDialog | shipped | DialogTests |
| PermissionRequestDialog | shipped | DialogTests |
| ChatScreen composition | shipped | ChatScreenTests |

## Deferred (acknowledged scope)

These reference components are not yet ported. Add tasks before shipping any
flow that needs them:

- Welcome banner: light theme + Apple_Terminal variant (only dark default ships)
- PromptInput vim mode, IDE selection, paste image refs, fast mode picker,
  thinking toggle, history search, command suggestions
- MessageSelector (resume / jump to)
- HighlightedCode (markdown + syntax highlighting)
- FileEditToolDiff (per-tool result UI)
- AgentProgressLine, CoordinatorAgentStatus, Tasks dialog
- MCP elicitation dialog, OAuth flow UI, Bridge dialog
- ResumeConversation, ExportDialog, ExitFlow
- Notifications surface (`PromptInput/Notifications.tsx`)

## Snapshot normalization

`renderViewToScreen` produces a deterministic `Screen` that test code converts
to a row-wise text representation. Snapshots compare normalized text:

- Trailing spaces stripped
- Cursor position not embedded (separate test)
- Spinner frame substituted with frame 0 unless test pins a specific frame

Dynamic strings (version, cwd) are passed into views as parameters rather than
read from globals, so tests stay reproducible.

## Architectural deviations from reference

- We do not use React or a reconciler. Each frame, the app re-renders the full
  view tree from state and a row-based diff against the previous frame emits
  minimal ANSI updates.
- We do not ship the custom Ink renderer / DOM / events / hooks. Behaviour is
  approximated by `App` (actor), `EventLoop` (thread), `Yoga` (in-house
  calculator), and `ScreenDiff` (renderer).
- We use a single dark theme. Theme switching is out of scope.
```

- [ ] **Step 2: Append TUI section to final-report**

Add to `docs/parity/final-report.md`:

```markdown
## Terminal UI (added 2026-05-23)

The line-based REPL was replaced with a real interactive TUI driven by
`App<ChatScreenState>` in `SwiftCodeTerminalUI`. See
`docs/parity/ui-contract.md` for the component shipping matrix and known gaps.

Test coverage:
- 9 new test suites under `Tests/SwiftCodeTerminalUITests/`
- snapshot-equivalent assertions via `renderViewToScreen` helper
```

- [ ] **Step 3: Run the full test suite**

```bash
swift test 2>&1 | tail -20
```

Expected: all tests pass.

- [ ] **Step 4: Manual interactive smoke**

```bash
swift build -c release
cp .build/release/swiftcode dist/swiftcode
./dist/swiftcode
```

Expected (visually):
- Alt screen takes over
- Welcome banner with orange "Welcome to Swift Code" line and Clawd ASCII art appears
- Bordered prompt input box at the bottom with `> ` and dim placeholder
- Typing inserts characters; Backspace deletes; arrow keys move cursor
- Enter submits; spinner appears while loading
- Assistant response renders inline above with `●` marker
- Ctrl-C exits cleanly; terminal returns to normal screen + cursor visible

- [ ] **Step 5: Commit**

```bash
git add docs/parity/ui-contract.md docs/parity/final-report.md
git commit -m "docs(parity): TUI contract + final report update"
```

---

## Task 12: Slash Command Autocomplete

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/Components/PromptInput/SuggestionOverlay.swift`
- Create: `Sources/SwiftCodeTerminalUI/Components/PromptInput/SlashCommandSuggestions.swift`
- Modify: `Sources/SwiftCodeTerminalUI/ChatScreen.swift` (extend `ChatScreenState` + render overlay below PromptInput when suggestions visible)
- Modify: `Sources/SwiftCodeTerminalUI/App/REPLReducer.swift` (Up/Down/Tab/Enter routing when suggestions visible; recompute on text change)
- Modify: `Sources/SwiftCodeCLI/InteractiveREPL.swift` (pass `[CommandSuggestion]` list into reducer)
- Test: `Tests/SwiftCodeTerminalUITests/SlashCommandSuggestionTests.swift`

**Behavior to match (reference: `.reference/src/utils/suggestions/commandSuggestions.ts` + `PromptInput.tsx`):**

- Trigger: cursor is inside a slash-command token. Token = `/` at start-of-line or after whitespace, followed by `[a-zA-Z][a-zA-Z0-9:\-_]*` (empty allowed right after `/`).
- Suggestion list filtered by prefix (case-insensitive). Reference uses Fuse.js fuzzy; we ship simple prefix + substring scoring (fuzzy deferred; documented in `ui-contract.md`).
- Max 6 visible suggestions; if more match, append `+N more` hint.
- Row: `> /{name}` (selected, theme.claude) or `  /{name}` (unselected), then spacer, then dim description right-aligned.
- Keyboard while visible: `Up`/`Down` move selection (clamp), `Tab`/`Enter` insert `/{name} `, `Esc` dismiss, anything else passes through.

- [ ] **Step 1: Write failing tests**

`Tests/SwiftCodeTerminalUITests/SlashCommandSuggestionTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class SlashCommandSuggestionTests: XCTestCase {
    private let registry: [CommandSuggestion] = [
        CommandSuggestion(name: "help", description: "Show available commands"),
        CommandSuggestion(name: "clear", description: "Clear conversation"),
        CommandSuggestion(name: "exit", description: "Exit"),
        CommandSuggestion(name: "config", description: "Configuration"),
    ]

    func testTriggerAtStartOfEmptyLine() {
        let trigger = SlashCommandSuggestions.detectTrigger(text: "/", cursorOffset: 1)
        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.tokenStart, 0)
        XCTAssertEqual(trigger?.prefix, "")
    }

    func testTriggerAfterWhitespace() {
        let trigger = SlashCommandSuggestions.detectTrigger(text: "hello /he", cursorOffset: 9)
        XCTAssertEqual(trigger?.tokenStart, 6)
        XCTAssertEqual(trigger?.prefix, "he")
    }

    func testNoTriggerInsideWord() {
        XCTAssertNil(SlashCommandSuggestions.detectTrigger(text: "foo/bar", cursorOffset: 7))
    }

    func testFilterReturnsMatchingByPrefix() {
        let matches = SlashCommandSuggestions.filter(prefix: "c", commands: registry)
        XCTAssertEqual(matches.map(\.name), ["clear", "config"])
    }

    func testApplyReplacesTokenWithSelectedCommand() {
        let cursor = TextCursor(text: "hello /he", offset: 9)
        let updated = SlashCommandSuggestions.apply(
            cursor: cursor,
            trigger: SlashTrigger(tokenStart: 6, prefix: "he"),
            selection: CommandSuggestion(name: "help", description: "Show available commands")
        )
        XCTAssertEqual(updated.text, "hello /help ")
        XCTAssertEqual(updated.offset, 12)
    }

    func testOverlayRendersSelectedRowHighlighted() {
        let items = registry.prefix(3).map { SuggestionItem.command($0) }
        let view = SuggestionOverlay(items: Array(items), selectedIndex: 1, width: 40)
        let screen = renderViewToScreen(view, width: 40, height: 5)
        // selected row is index 1 inside the rounded box (row 0 is border)
        let row2 = (0..<40).map { String(screen.cell(at: $0, row: 2).character) }.joined()
        XCTAssertTrue(row2.contains("> /clear"))
    }
}
```

- [ ] **Step 2: Run, verify fail**

```bash
swift test --filter SlashCommandSuggestionTests
```

- [ ] **Step 3: Implement SlashCommandSuggestions**

`Sources/SwiftCodeTerminalUI/Components/PromptInput/SlashCommandSuggestions.swift`:

```swift
public struct CommandSuggestion: Sendable, Equatable {
    public let name: String
    public let description: String
    public init(name: String, description: String) {
        self.name = name; self.description = description
    }
}

public struct SlashTrigger: Sendable, Equatable {
    public let tokenStart: Int
    public let prefix: String
    public init(tokenStart: Int, prefix: String) {
        self.tokenStart = tokenStart; self.prefix = prefix
    }
}

public enum SlashCommandSuggestions {
    public static func detectTrigger(text: String, cursorOffset: Int) -> SlashTrigger? {
        let chars = Array(text)
        guard cursorOffset >= 0 && cursorOffset <= chars.count else { return nil }
        var i = cursorOffset - 1
        while i >= 0 {
            let ch = chars[i]
            if ch == "/" {
                let isStart = (i == 0) || chars[i - 1].isWhitespace
                if !isStart { return nil }
                let prefixChars = Array(chars[(i + 1)..<cursorOffset])
                if prefixChars.contains(where: { !isCommandChar($0) }) { return nil }
                return SlashTrigger(tokenStart: i, prefix: String(prefixChars))
            }
            if !isCommandChar(ch) { return nil }
            i -= 1
        }
        return nil
    }

    public static func filter(prefix: String, commands: [CommandSuggestion]) -> [CommandSuggestion] {
        guard !prefix.isEmpty else { return commands }
        let lower = prefix.lowercased()
        return commands.filter { $0.name.lowercased().hasPrefix(lower) }
    }

    public static func apply(cursor: TextCursor, trigger: SlashTrigger,
                             selection: CommandSuggestion) -> TextCursor {
        let chars = Array(cursor.text)
        let before = String(chars[0..<trigger.tokenStart])
        let after  = String(chars[cursor.offset..<chars.count])
        let inserted = "/\(selection.name) "
        let newText = before + inserted + after
        let newOffset = (before + inserted).count
        return TextCursor(text: newText, offset: newOffset)
    }

    private static func isCommandChar(_ ch: Character) -> Bool {
        return ch.isLetter || ch.isNumber || ch == ":" || ch == "-" || ch == "_"
    }
}
```

- [ ] **Step 4: Implement SuggestionOverlay (shared with at-mention)**

`Sources/SwiftCodeTerminalUI/Components/PromptInput/SuggestionOverlay.swift`:

```swift
public enum SuggestionItem: Sendable, Equatable {
    case command(CommandSuggestion)
    case path(PathSuggestion)
}

public struct PathSuggestion: Sendable, Equatable {
    public let display: String
    public let isDirectory: Bool
    public init(display: String, isDirectory: Bool) {
        self.display = display; self.isDirectory = isDirectory
    }
}

public struct SuggestionOverlay: View {
    public let items: [SuggestionItem]
    public let selectedIndex: Int
    public let width: Int
    public let maxVisible: Int

    public init(items: [SuggestionItem], selectedIndex: Int, width: Int, maxVisible: Int = 6) {
        self.items = items; self.selectedIndex = selectedIndex
        self.width = width; self.maxVisible = maxVisible
    }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        guard !items.isEmpty else {
            return BoxView(width: .fixed(width), height: .fixed(0))
                .buildLayoutNode(theme: theme, styles: styles)
        }
        let visible = Array(items.prefix(maxVisible))
        var rows: [any View] = visible.enumerated().map { idx, item in
            row(item: item, selected: idx == selectedIndex, theme: theme)
        }
        if items.count > maxVisible {
            rows.append(TextView("+\(items.count - maxVisible) more", dim: true))
        }
        return BoxView(width: .fixed(width),
                       padding: EdgeInsets(horizontal: 1),
                       border: .rounded, borderColor: .ansi256(240),
                       flexDirection: .column, children: rows)
            .buildLayoutNode(theme: theme, styles: styles)
    }

    private func row(item: SuggestionItem, selected: Bool, theme: Theme) -> any View {
        let (lhs, rhs): (String, String)
        switch item {
        case .command(let c):
            lhs = "/\(c.name)"; rhs = c.description
        case .path(let p):
            lhs = p.display; rhs = p.isDirectory ? "directory" : "file"
        }
        let marker = selected ? "> " : "  "
        return BoxView(width: .auto, flexDirection: .row, children: [
            TextView(marker, color: selected ? theme.claude : .default),
            TextView(lhs, color: selected ? theme.claude : .default),
            SpacerView(),
            TextView(rhs, dim: true),
        ])
    }
}
```

- [ ] **Step 5: Extend ChatScreenState + REPLReducer**

In `Sources/SwiftCodeTerminalUI/ChatScreen.swift`, extend `ChatScreenState`:

```swift
public var suggestions: [SuggestionItem] = []
public var suggestionSelectedIndex: Int = 0
public var suggestionTrigger: SuggestionTriggerKind? = nil
public var workingDirectory: String = FileManager.default.currentDirectoryPath
public var availableCommands: [CommandSuggestion] = []

public enum SuggestionTriggerKind: Sendable, Equatable {
    case slash(SlashTrigger)
    case atMention(AtMentionTrigger)  // wired in Task 13
}
```

Render the overlay between PromptInput row and footer:

```swift
if !state.suggestions.isEmpty {
    rows.append(SuggestionOverlay(items: state.suggestions,
                                  selectedIndex: state.suggestionSelectedIndex,
                                  width: max(20, /* width passed by parent */ 80)))
}
```

Replace `REPLReducer.apply`:

```swift
public enum REPLReducer {
    public static func apply(event: InputEvent, to state: inout ChatScreenState) {
        // Suggestion-active routing first
        if state.suggestionTrigger != nil {
            switch event {
            case .arrowUp:
                state.suggestionSelectedIndex = max(0, state.suggestionSelectedIndex - 1)
                return
            case .arrowDown:
                state.suggestionSelectedIndex = min(state.suggestions.count - 1,
                                                    state.suggestionSelectedIndex + 1)
                return
            case .escape:
                state.suggestions = []
                state.suggestionTrigger = nil
                state.suggestionSelectedIndex = 0
                return
            case .character(let c) where c == "\t" || c == "\n":
                applySelectedSuggestion(state: &state)
                return
            default: break
            }
        }
        // Normal input
        switch event {
        case .character(let c):
            if c == "\n" { return }   // submit handled by caller
            state.cursor.insert(String(c))
        case .backspace: state.cursor.backspace()
        case .delete:    state.cursor.delete()
        case .arrowLeft: state.cursor.moveLeft()
        case .arrowRight: state.cursor.moveRight()
        case .paste(let s): state.cursor.insert(s)
        default: break
        }
        recomputeSuggestions(state: &state)
    }

    static func recomputeSuggestions(state: inout ChatScreenState) {
        if let slash = SlashCommandSuggestions.detectTrigger(
            text: state.cursor.text, cursorOffset: state.cursor.offset) {
            state.suggestionTrigger = .slash(slash)
            state.suggestions = SlashCommandSuggestions
                .filter(prefix: slash.prefix, commands: state.availableCommands)
                .prefix(20).map { .command($0) }
        } else {
            // At-mention path wired in Task 13
            state.suggestions = []
            state.suggestionTrigger = nil
        }
        if state.suggestionSelectedIndex >= state.suggestions.count {
            state.suggestionSelectedIndex = 0
        }
    }

    static func applySelectedSuggestion(state: inout ChatScreenState) {
        guard state.suggestionSelectedIndex < state.suggestions.count else { return }
        let pick = state.suggestions[state.suggestionSelectedIndex]
        switch (state.suggestionTrigger, pick) {
        case (.slash(let trig)?, .command(let cmd)):
            state.cursor = SlashCommandSuggestions.apply(cursor: state.cursor, trigger: trig, selection: cmd)
        // .atMention case wired in Task 13
        default: break
        }
        state.suggestions = []
        state.suggestionTrigger = nil
        state.suggestionSelectedIndex = 0
    }
}
```

- [ ] **Step 6: Wire availableCommands in InteractiveREPL**

When constructing initial `ChatScreenState`, populate `availableCommands` from `await registry.listCommands()` (or equivalent — adapt to the actual `CommandRegistry` API). Each entry maps to `CommandSuggestion(name: ..., description: ...)`.

- [ ] **Step 7: Run all suggestion tests**

```bash
swift test --filter SlashCommandSuggestionTests
swift build
```

- [ ] **Step 8: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/Components/PromptInput/SuggestionOverlay.swift \
        Sources/SwiftCodeTerminalUI/Components/PromptInput/SlashCommandSuggestions.swift \
        Sources/SwiftCodeTerminalUI/ChatScreen.swift \
        Sources/SwiftCodeTerminalUI/App/REPLReducer.swift \
        Sources/SwiftCodeCLI/InteractiveREPL.swift \
        Tests/SwiftCodeTerminalUITests/SlashCommandSuggestionTests.swift
git commit -m "feat(tui): slash command autocomplete in prompt input"
```

---

## Task 13: File `@`-Mention Autocomplete

**Files:**
- Create: `Sources/SwiftCodeTerminalUI/Components/PromptInput/AtMentionSuggestions.swift`
- Create: `Sources/SwiftCodeNative/PathCompletion.swift`
- Modify: `Sources/SwiftCodeTerminalUI/App/REPLReducer.swift` (handle `@` trigger + route apply for `.atMention`)
- Modify: `Sources/SwiftCodeCLI/InteractiveREPL.swift` (pass `workingDirectory` into state)
- Test: `Tests/SwiftCodeTerminalUITests/AtMentionSuggestionTests.swift`
- Test: `Tests/SwiftCodeNativeTests/PathCompletionTests.swift`

**Behavior to match (reference: `.reference/src/utils/suggestions/directoryCompletion.ts` + `PromptInput.tsx:1283-1297`):**

- Trigger: cursor inside `@`-token. Token = `@` at start-of-line or after whitespace, then path-like chars (letters, digits, `/`, `.`, `-`, `_`).
- Suggestions are filesystem entries under `cwd + dir(partialPath)`, filtered by `basename(partialPath)` prefix.
- Hidden entries (`.foo`) excluded unless prefix starts with `.`.
- Directories shown with `directory` description, files with `file`. Result list sorted alphabetically (case-insensitive).
- On Tab/Enter for a file: replace token with `@{relativePath} ` (trailing space). For a directory: replace with `@{path}/` (trailing slash, no space — user can keep typing children).

- [ ] **Step 1: Write failing PathCompletion tests**

`Tests/SwiftCodeNativeTests/PathCompletionTests.swift`:

```swift
import XCTest
@testable import SwiftCodeNative

final class PathCompletionTests: XCTestCase {
    var tmp: URL!
    override func setUp() {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        for name in ["alpha.txt", "beta.txt", "subdir", ".hidden"] {
            let url = tmp.appendingPathComponent(name)
            if name == "subdir" {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
        }
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testTopLevelCompletionsExcludeHidden() throws {
        let entries = try PathCompletion.complete(prefix: "", in: tmp.path)
        let names = entries.map(\.name).sorted()
        XCTAssertEqual(names, ["alpha.txt", "beta.txt", "subdir"])
    }

    func testHiddenIncludedWhenPrefixStartsWithDot() throws {
        let entries = try PathCompletion.complete(prefix: ".", in: tmp.path)
        XCTAssertTrue(entries.contains { $0.name == ".hidden" })
    }

    func testPrefixFilters() throws {
        let entries = try PathCompletion.complete(prefix: "a", in: tmp.path)
        XCTAssertEqual(entries.map(\.name), ["alpha.txt"])
    }

    func testDirectoryFlag() throws {
        let entries = try PathCompletion.complete(prefix: "", in: tmp.path)
        XCTAssertEqual(entries.first { $0.name == "subdir" }?.kind, .directory)
    }
}
```

- [ ] **Step 2: Implement PathCompletion**

`Sources/SwiftCodeNative/PathCompletion.swift`:

```swift
import Foundation

public enum PathCompletion {
    public enum Kind: Sendable, Equatable { case file, directory }
    public struct Entry: Sendable, Equatable {
        public let name: String
        public let kind: Kind
        public init(name: String, kind: Kind) { self.name = name; self.kind = kind }
    }

    public static func complete(prefix: String, in directory: String) throws -> [Entry] {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: directory)
        let keys: [URLResourceKey] = [.isDirectoryKey]
        let entries = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [])
        let includeHidden = prefix.hasPrefix(".")
        let mapped = entries.compactMap { (entry: URL) -> Entry? in
            let name = entry.lastPathComponent
            if !includeHidden && name.hasPrefix(".") { return nil }
            if !prefix.isEmpty && !name.lowercased().hasPrefix(prefix.lowercased()) { return nil }
            let isDir = (try? entry.resourceValues(forKeys: Set(keys)))?.isDirectory ?? false
            return Entry(name: name, kind: isDir ? .directory : .file)
        }
        return mapped.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}
```

Run `swift test --filter PathCompletionTests` → PASS.

- [ ] **Step 3: Write failing AtMentionSuggestionTests**

`Tests/SwiftCodeTerminalUITests/AtMentionSuggestionTests.swift`:

```swift
import XCTest
@testable import SwiftCodeTerminalUI

final class AtMentionSuggestionTests: XCTestCase {
    func testTriggerAtStart() {
        let t = AtMentionSuggestions.detectTrigger(text: "@", cursorOffset: 1)
        XCTAssertEqual(t?.tokenStart, 0)
        XCTAssertEqual(t?.partialPath, "")
    }

    func testTriggerInsideToken() {
        let t = AtMentionSuggestions.detectTrigger(text: "see @src/ma", cursorOffset: 11)
        XCTAssertEqual(t?.tokenStart, 4)
        XCTAssertEqual(t?.partialPath, "src/ma")
    }

    func testSplitDirectoryAndPrefix() {
        let split = AtMentionSuggestions.splitDirectoryAndPrefix("src/ma")
        XCTAssertEqual(split.directory, "src")
        XCTAssertEqual(split.prefix, "ma")
        XCTAssertEqual(AtMentionSuggestions.splitDirectoryAndPrefix("foo").directory, "")
        XCTAssertEqual(AtMentionSuggestions.splitDirectoryAndPrefix("src/").prefix, "")
    }

    func testApplyForFileInsertsRelativePathWithTrailingSpace() {
        let cursor = TextCursor(text: "see @src/ma", offset: 11)
        let updated = AtMentionSuggestions.apply(
            cursor: cursor,
            trigger: AtMentionTrigger(tokenStart: 4, partialPath: "src/ma"),
            selection: PathSuggestion(display: "src/main.swift", isDirectory: false)
        )
        XCTAssertEqual(updated.text, "see @src/main.swift ")
        XCTAssertEqual(updated.offset, 20)
    }

    func testApplyForDirectoryInsertsTrailingSlashNoSpace() {
        let cursor = TextCursor(text: "see @src", offset: 8)
        let updated = AtMentionSuggestions.apply(
            cursor: cursor,
            trigger: AtMentionTrigger(tokenStart: 4, partialPath: "src"),
            selection: PathSuggestion(display: "src", isDirectory: true)
        )
        XCTAssertEqual(updated.text, "see @src/")
        XCTAssertEqual(updated.offset, 9)
    }
}
```

- [ ] **Step 4: Implement AtMentionSuggestions**

`Sources/SwiftCodeTerminalUI/Components/PromptInput/AtMentionSuggestions.swift`:

```swift
public struct AtMentionTrigger: Sendable, Equatable {
    public let tokenStart: Int
    public let partialPath: String
    public init(tokenStart: Int, partialPath: String) {
        self.tokenStart = tokenStart; self.partialPath = partialPath
    }
}

public enum AtMentionSuggestions {
    public static func detectTrigger(text: String, cursorOffset: Int) -> AtMentionTrigger? {
        let chars = Array(text)
        guard cursorOffset >= 0 && cursorOffset <= chars.count else { return nil }
        var i = cursorOffset - 1
        while i >= 0 {
            let ch = chars[i]
            if ch == "@" {
                let isStart = (i == 0) || chars[i - 1].isWhitespace
                if !isStart { return nil }
                let partial = String(chars[(i + 1)..<cursorOffset])
                if partial.contains(where: { !isPathChar($0) }) { return nil }
                return AtMentionTrigger(tokenStart: i, partialPath: partial)
            }
            if !isPathChar(ch) { return nil }
            i -= 1
        }
        return nil
    }

    public static func splitDirectoryAndPrefix(_ partial: String) -> (directory: String, prefix: String) {
        if let lastSlash = partial.lastIndex(of: "/") {
            let dir = String(partial[partial.startIndex..<lastSlash])
            let prefix = String(partial[partial.index(after: lastSlash)..<partial.endIndex])
            return (dir, prefix)
        }
        return ("", partial)
    }

    public static func apply(cursor: TextCursor, trigger: AtMentionTrigger,
                             selection: PathSuggestion) -> TextCursor {
        let chars = Array(cursor.text)
        let before = String(chars[0..<trigger.tokenStart])
        let after  = String(chars[cursor.offset..<chars.count])
        let display = selection.display.hasSuffix("/")
            ? String(selection.display.dropLast())
            : selection.display
        let inserted = selection.isDirectory ? "@\(display)/" : "@\(display) "
        let newText = before + inserted + after
        let newOffset = (before + inserted).count
        return TextCursor(text: newText, offset: newOffset)
    }

    private static func isPathChar(_ ch: Character) -> Bool {
        return ch.isLetter || ch.isNumber || ch == "/" || ch == "." || ch == "-" || ch == "_"
    }
}
```

- [ ] **Step 5: Extend REPLReducer for @ trigger**

In `REPLReducer.recomputeSuggestions`, after the slash branch's `if`:

```swift
else if let at = AtMentionSuggestions.detectTrigger(
    text: state.cursor.text, cursorOffset: state.cursor.offset) {
    let split = AtMentionSuggestions.splitDirectoryAndPrefix(at.partialPath)
    let scanDir = split.directory.isEmpty
        ? state.workingDirectory
        : "\(state.workingDirectory)/\(split.directory)"
    let entries = (try? PathCompletion.complete(prefix: split.prefix, in: scanDir)) ?? []
    if !entries.isEmpty {
        state.suggestionTrigger = .atMention(at)
        state.suggestions = entries.prefix(20).map {
            .path(PathSuggestion(
                display: split.directory.isEmpty ? $0.name : "\(split.directory)/\($0.name)",
                isDirectory: $0.kind == .directory
            ))
        }
    } else {
        state.suggestions = []; state.suggestionTrigger = nil
    }
}
```

In `applySelectedSuggestion`, add:

```swift
case (.atMention(let trig)?, .path(let p)):
    state.cursor = AtMentionSuggestions.apply(cursor: state.cursor, trigger: trig, selection: p)
```

Add `import SwiftCodeNative` to the reducer file.

- [ ] **Step 6: Wire workingDirectory**

In `InteractiveREPL.run()`, when constructing `ChatScreenState`, set `workingDirectory = FileManager.default.currentDirectoryPath`.

- [ ] **Step 7: Run all suggestion tests**

```bash
swift test --filter "AtMentionSuggestionTests|PathCompletionTests"
swift build
```

- [ ] **Step 8: Commit**

```bash
git add Sources/SwiftCodeTerminalUI/Components/PromptInput/AtMentionSuggestions.swift \
        Sources/SwiftCodeNative/PathCompletion.swift \
        Sources/SwiftCodeTerminalUI/App/REPLReducer.swift \
        Sources/SwiftCodeCLI/InteractiveREPL.swift \
        Tests/SwiftCodeTerminalUITests/AtMentionSuggestionTests.swift \
        Tests/SwiftCodeNativeTests/PathCompletionTests.swift
git commit -m "feat(tui): file @-mention autocomplete in prompt input"
```

---

## Self-Review

**Spec coverage:**
- Goal "make TUI look like reference" → Tasks 6 (welcome), 7 (prompt), 8 (messages), 9 (chat composition + REPL rewrite), 10 (dialogs). ✓
- "Real interactive (raw mode, alt-screen, repaint, keypress)" → Tasks 1, 2, 5. ✓
- "Layout matches reference" → Task 3. ✓
- "Theme colors" → Task 4. ✓
- "Spinner animates" → Task 8 + 9. ✓
- "At least one permission dialog" → Task 10. ✓
- "REPL replaced" → Task 9. ✓
- "Coverage doc + snapshot baseline" → Task 11. ✓

**Placeholder scan:** Every code block contains executable code or fully-specified test text. Note: Task 9 Step 7 contains an illustrative `extension App where State == ChatScreenState` whose method bodies were placeholders — those are concretized in the same step right after `withState` is defined. The implementer must use the concrete bodies, not the placeholder versions.

**Type consistency:**
- `TextCursor` defined in Task 7, used in Tasks 8 (via state), 9 (ChatScreenState). ✓
- `ChatScreenState` defined in Task 9, referenced by Task 9 itself only. ✓
- `Screen`, `StyleTable`, `CellStyle`, `CellColor` defined in Task 1, used everywhere. ✓
- `View` protocol, `LayoutNode`, `paint(node:into:)`, `renderViewToScreen` defined in Task 4, used in Tasks 6, 7, 8, 9, 10. ✓
- `YogaNode.flexGrow`/`gap`/`alignSelf`/`display` added in Task 3, used in Tasks 4 (BoxView with gap/flexGrow), 8 (WrappedTextView with flexGrow). ✓
- `App.withState`/`tickSpinner`/`renderFrameIfNeeded`/`renderInitialFrame` declared in Task 5, used in Task 9. ✓
- `InputEvent.resize(width:height:)` added in Task 5, used in Task 5 tests. ✓
- `InputEvent.paste(_:)` already exists in current codebase (verified in `Events/InputReader.swift`). ✓

**One known sharp edge documented up front:** `WrappedTextView` in Task 8 mutates `layoutHeight` during paint after layout has completed. The plan acknowledges this and treats it as a v1 trade-off; a future task can introduce a measure phase. Tests still pass because parent uses `flexGrow:1` and isn't sized to children.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-23-terminal-ui-parity.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review between tasks, fast iteration. Sonnet for implementers, Haiku for reviewers (matches the `/e` skill convention used for the prior Swift port).
2. **Inline Execution** — execute tasks in this session using `executing-plans`, batch with checkpoints.
