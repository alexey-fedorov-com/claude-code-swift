import XCTest
@testable import SwiftCodeTerminalUI

final class AnsiEscapesTests: XCTestCase {
    func testCursorPosition() {
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
