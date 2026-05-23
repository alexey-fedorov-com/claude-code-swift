import XCTest
@testable import SwiftCodeTerminalUI

final class StyleTableTests: XCTestCase {
    func testDefaultStyleHasIdZero() {
        let table = CellStyleTable()
        XCTAssertEqual(table.id(for: .default), 0)
    }

    func testInterningReturnsSameId() {
        let table = CellStyleTable()
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
