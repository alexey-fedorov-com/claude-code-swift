import XCTest
@testable import SwiftCodeTerminalUI

final class ScreenDiffTests: XCTestCase {
    func testEmptyDiffIsEmpty() {
        let a = Screen(width: 5, height: 2)
        let b = Screen(width: 5, height: 2)
        XCTAssertEqual(ScreenDiff.compute(prev: a, next: b, styles: CellStyleTable()), "")
    }

    func testSingleCellChange() {
        let styles = CellStyleTable()
        let a = Screen(width: 5, height: 1)
        var b = Screen(width: 5, height: 1)
        b.write(text: "x", at: 2, row: 0, styleId: 0)
        let out = ScreenDiff.compute(prev: a, next: b, styles: styles)
        XCTAssertTrue(out.contains("\u{1B}[1;3H"))
        XCTAssertTrue(out.contains("x"))
    }

    func testRowFullRewrite() {
        let styles = CellStyleTable()
        let a = Screen(width: 5, height: 1)
        var b = Screen(width: 5, height: 1)
        b.write(text: "hello", at: 0, row: 0, styleId: 0)
        let out = ScreenDiff.compute(prev: a, next: b, styles: styles)
        XCTAssertTrue(out.contains("\u{1B}[1;1H"))
        XCTAssertTrue(out.contains("hello"))
    }

    func testFirstFrameClearsAndPaints() {
        let styles = CellStyleTable()
        var b = Screen(width: 5, height: 1)
        b.write(text: "hi", at: 0, row: 0, styleId: 0)
        let out = ScreenDiff.computeInitial(next: b, styles: styles)
        XCTAssertTrue(out.contains("\u{1B}[2J"))
        XCTAssertTrue(out.contains("hi"))
    }
}
