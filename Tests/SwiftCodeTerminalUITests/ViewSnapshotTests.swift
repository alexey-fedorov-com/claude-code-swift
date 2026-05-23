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
        let view: any View = TextView("hi")
        let screen = renderViewToScreen(view, width: 10, height: 1)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "h")
        XCTAssertEqual(screen.cell(at: 1, row: 0).character, "i")
    }

    func testRenderBoxWithBorder() {
        let view: any View = BoxView(width: .fixed(5), height: .fixed(3),
                                     border: .rounded,
                                     children: [TextView("X")])
        let screen = renderViewToScreen(view, width: 10, height: 5)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "╭")
        XCTAssertEqual(screen.cell(at: 4, row: 0).character, "╮")
        XCTAssertEqual(screen.cell(at: 0, row: 2).character, "╰")
        XCTAssertEqual(screen.cell(at: 4, row: 2).character, "╯")
        XCTAssertEqual(screen.cell(at: 1, row: 1).character, "X")
    }

    func testRenderSpinnerWithFrameZero() {
        let view: any View = SpinnerView(frameIndex: 0)
        let screen = renderViewToScreen(view, width: 2, height: 1)
        XCTAssertEqual(String(screen.cell(at: 0, row: 0).character), Spinner.dotsFrames[0])
    }

    func testNewlineConsumesOneRow() {
        let view: any View = BoxView(flexDirection: .column, children: [
            TextView("a"), NewlineView(), TextView("b")
        ])
        let screen = renderViewToScreen(view, width: 5, height: 3)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "a")
        XCTAssertEqual(screen.cell(at: 0, row: 2).character, "b")
    }

    func testSpacerFlexGrowsToFillRow() {
        let view: any View = BoxView(width: .fixed(10), height: .fixed(1),
                                     flexDirection: .row, children: [
            TextView("a"), SpacerView(), TextView("z")
        ])
        let screen = renderViewToScreen(view, width: 10, height: 1)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "a")
        XCTAssertEqual(screen.cell(at: 9, row: 0).character, "z")
    }
}
