import XCTest
@testable import SwiftCodeTerminalUI

final class PromptInputTests: XCTestCase {
    func testInsertAtCursor() {
        var c = TextCursor(text: "hello", offset: 5)
        c.insert("!")
        XCTAssertEqual(c.text, "hello!")
        XCTAssertEqual(c.offset, 6)
    }

    func testInsertInMiddle() {
        var c = TextCursor(text: "helo", offset: 3)
        c.insert("l")
        XCTAssertEqual(c.text, "hello")
        XCTAssertEqual(c.offset, 4)
    }

    func testBackspace() {
        var c = TextCursor(text: "hello", offset: 5)
        c.backspace()
        XCTAssertEqual(c.text, "hell")
        XCTAssertEqual(c.offset, 4)
    }

    func testBackspaceAtStartIsNoop() {
        var c = TextCursor(text: "hello", offset: 0)
        c.backspace()
        XCTAssertEqual(c.text, "hello")
        XCTAssertEqual(c.offset, 0)
    }

    func testDeleteAtCursor() {
        var c = TextCursor(text: "hello", offset: 0)
        c.delete()
        XCTAssertEqual(c.text, "ello")
        XCTAssertEqual(c.offset, 0)
    }

    func testMoveLeftRight() {
        var c = TextCursor(text: "abc", offset: 3)
        c.moveLeft()
        XCTAssertEqual(c.offset, 2)
        c.moveRight()
        XCTAssertEqual(c.offset, 3)
        c.moveRight()  // clamped at end
        XCTAssertEqual(c.offset, 3)
        c.moveLeft(); c.moveLeft(); c.moveLeft()
        XCTAssertEqual(c.offset, 0)
        c.moveLeft()   // clamped at start
        XCTAssertEqual(c.offset, 0)
    }

    func testMoveHomeAndEnd() {
        var c = TextCursor(text: "abc", offset: 2)
        c.moveHome()
        XCTAssertEqual(c.offset, 0)
        c.moveEnd()
        XCTAssertEqual(c.offset, 3)
    }

    func testRenderPromptInputBoxWithPlaceholder() {
        let view = PromptInput(cursor: TextCursor(text: "", offset: 0),
                               placeholder: "Try \"how does X work?\"",
                               width: 40)
        let screen = renderViewToScreen(view, width: 40, height: 3)
        // Rounded border corners
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "╭")
        XCTAssertEqual(screen.cell(at: 39, row: 0).character, "╮")
        XCTAssertEqual(screen.cell(at: 0, row: 2).character, "╰")
        XCTAssertEqual(screen.cell(at: 39, row: 2).character, "╯")
        // ">" prompt marker on row 1, col 2 (after border + padding)
        XCTAssertEqual(screen.cell(at: 2, row: 1).character, ">")
    }

    func testRenderPromptInputBoxWithTypedText() {
        let view = PromptInput(cursor: TextCursor(text: "hello", offset: 5),
                               placeholder: "...",
                               width: 40)
        let screen = renderViewToScreen(view, width: 40, height: 3)
        XCTAssertEqual(screen.cell(at: 4, row: 1).character, "h")
        XCTAssertEqual(screen.cell(at: 5, row: 1).character, "e")
        XCTAssertEqual(screen.cell(at: 6, row: 1).character, "l")
        XCTAssertEqual(screen.cell(at: 7, row: 1).character, "l")
        XCTAssertEqual(screen.cell(at: 8, row: 1).character, "o")
    }

    func testFooterRendersShortcutsAndMode() {
        let view = PromptInputFooter(modeLabel: "Plan Mode",
                                     modeColor: .ansi256(99),
                                     shortcuts: ["⏎ send", "? help"],
                                     cwd: "/tmp")
        let screen = renderViewToScreen(view, width: 60, height: 1)
        let row = (0..<60).map { String(screen.cell(at: $0, row: 0).character) }.joined()
        XCTAssertTrue(row.contains("Plan Mode"))
        XCTAssertTrue(row.contains("⏎ send"))
        XCTAssertTrue(row.contains("/tmp"))
    }
}
