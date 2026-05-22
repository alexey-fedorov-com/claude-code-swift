import XCTest
@testable import SwiftCodeTerminalUI

final class YogaLayoutTests: XCTestCase {

    private let calc = YogaCalculator()

    // MARK: - Fixed-width box

    func testFixedWidthBox() {
        let node = YogaNode()
        node.width = .fixed(40)
        node.height = .fixed(10)
        calc.calculate(root: node, availableWidth: 80, availableHeight: 24)
        XCTAssertEqual(node.layoutWidth, 40)
        XCTAssertEqual(node.layoutHeight, 10)
    }

    // MARK: - Two text nodes in a row: side-by-side

    func testTwoTextNodesInRow() {
        let parent = YogaNode()
        parent.flexDirection = .row
        parent.width = .fixed(20)
        parent.height = .fixed(1)

        let left = YogaNode()
        left.text = "Hello"

        let right = YogaNode()
        right.text = "World"

        parent.addChild(left)
        parent.addChild(right)

        calc.calculate(root: parent, availableWidth: 80, availableHeight: 24)

        // Left child starts at x=0
        XCTAssertEqual(left.layoutX, 0, "left child x should be 0")
        // Right child starts after left child
        XCTAssertEqual(right.layoutX, left.layoutX + left.layoutWidth,
                       "right child x should follow left child")
    }

    // MARK: - Padding shrinks inner content area

    func testPaddingShrinkInnerArea() {
        let parent = YogaNode()
        parent.width = .fixed(20)
        parent.height = .fixed(10)
        parent.padding = EdgeInsets(all: 2)

        let child = YogaNode()
        child.text = "hi"

        parent.addChild(child)
        calc.calculate(root: parent, availableWidth: 80, availableHeight: 24)

        // Child should be inset by padding
        XCTAssertEqual(child.layoutX, 2, "child x should equal left padding")
        XCTAssertEqual(child.layoutY, 2, "child y should equal top padding")
        // Child width is bounded by inner width
        XCTAssertLessThanOrEqual(child.layoutWidth, 20 - 4,
                                 "child width should not exceed parent minus padding")
    }

    // MARK: - Width 100% fills parent

    func testWidthPercent() {
        let parent = YogaNode()
        parent.width = .fixed(60)
        parent.height = .fixed(5)

        let child = YogaNode()
        child.width = .percent(1.0)
        child.text = "fill"

        parent.addChild(child)
        calc.calculate(root: parent, availableWidth: 80, availableHeight: 24)

        XCTAssertEqual(child.layoutWidth, 60,
                       "100% width child should equal parent width")
    }

    // MARK: - justify-content: spaceBetween distributes children

    func testJustifyContentSpaceBetween() {
        let parent = YogaNode()
        parent.flexDirection = .row
        parent.justifyContent = .spaceBetween
        parent.width = .fixed(30)
        parent.height = .fixed(1)

        let a = YogaNode()
        a.width = .fixed(5)
        a.height = .fixed(1)
        a.text = "aaa"

        let b = YogaNode()
        b.width = .fixed(5)
        b.height = .fixed(1)
        b.text = "bbb"

        let c = YogaNode()
        c.width = .fixed(5)
        c.height = .fixed(1)
        c.text = "ccc"

        parent.addChild(a)
        parent.addChild(b)
        parent.addChild(c)

        calc.calculate(root: parent, availableWidth: 80, availableHeight: 24)

        // Total child width = 15, parent = 30, freeSpace = 15
        // spaceBetween: 15 / 2 = 7 gap between each pair
        // a at 0, b at 5+7=12, c at 12+5+8=25 (remainder distributed)
        XCTAssertEqual(a.layoutX, 0, "first child starts at 0")
        XCTAssertGreaterThan(b.layoutX, a.layoutX + a.layoutWidth,
                             "middle child should have gap after first")
        XCTAssertGreaterThan(c.layoutX, b.layoutX + b.layoutWidth,
                             "last child should have gap after middle")
        XCTAssertEqual(c.layoutX + c.layoutWidth, 30,
                       "last child right edge should reach parent width")
    }

    // MARK: - Margin shifts child position

    func testMargin() {
        let parent = YogaNode()
        parent.width = .fixed(40)
        parent.height = .fixed(20)

        let child = YogaNode()
        child.width = .fixed(10)
        child.height = .fixed(5)
        child.margin = EdgeInsets(top: 3, right: 0, bottom: 0, left: 5)
        child.text = "x"

        parent.addChild(child)
        calc.calculate(root: parent, availableWidth: 80, availableHeight: 24)

        XCTAssertEqual(child.layoutX, 5, "child x should include left margin")
        XCTAssertEqual(child.layoutY, 3, "child y should include top margin")
    }

    // MARK: - Auto width from text content

    func testAutoWidthFromText() {
        let node = YogaNode()
        node.text = "Hello World"
        // width/height default to .auto
        calc.calculate(root: node, availableWidth: 80, availableHeight: 24)
        // "Hello World" is 11 chars
        XCTAssertEqual(node.layoutWidth, 11, "auto width should match text length")
        XCTAssertEqual(node.layoutHeight, 1, "single line text has height 1")
    }

    // MARK: - Column direction stacks children vertically

    func testColumnDirectionStacksVertically() {
        let parent = YogaNode()
        parent.flexDirection = .column
        parent.width = .fixed(20)
        parent.height = .fixed(10)

        let top = YogaNode()
        top.height = .fixed(2)
        top.text = "top"

        let bottom = YogaNode()
        bottom.height = .fixed(3)
        bottom.text = "bottom"

        parent.addChild(top)
        parent.addChild(bottom)

        calc.calculate(root: parent, availableWidth: 80, availableHeight: 24)

        XCTAssertEqual(top.layoutY, 0, "first child starts at top")
        XCTAssertEqual(bottom.layoutY, top.layoutY + top.layoutHeight,
                       "second child starts immediately below first")
    }
}
