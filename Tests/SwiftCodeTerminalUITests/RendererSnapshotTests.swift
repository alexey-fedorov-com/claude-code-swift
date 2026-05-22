import XCTest
@testable import SwiftCodeTerminalUI

final class RendererSnapshotTests: XCTestCase {

    private let renderer = ANSIRenderer()
    private let calc = YogaCalculator()

    // MARK: - Helpers

    private func render(node: RenderNode, width: Int = 80, height: Int = 24) -> String {
        renderer.render(root: node, width: width, height: height)
    }

    // MARK: - Plain text

    func testRenderHello() {
        let yogaNode = YogaNode()
        yogaNode.text = "hello"
        calc.calculate(root: yogaNode, availableWidth: 80, availableHeight: 24)
        let renderNode = RenderNode.build(from: yogaNode)
        let output = render(node: renderNode)
        XCTAssertEqual(output, "hello", "Plain text renders as-is")
    }

    func testRenderEmptyString() {
        let yogaNode = YogaNode()
        yogaNode.text = ""
        calc.calculate(root: yogaNode, availableWidth: 80, availableHeight: 24)
        let renderNode = RenderNode.build(from: yogaNode)
        let output = render(node: renderNode)
        // Empty string should render without crash
        XCTAssertNotNil(output)
    }

    // MARK: - Box with border

    func testRenderBoxWithBorder() {
        // Build a box with a single-border and "hi" text inside
        let textComp = TextComponent("hi")
        let boxComp = BoxComponent(
            children: [.text(textComp)],
            width: .fixed(6),
            height: .fixed(3),
            border: .single
        )
        let yogaNode = boxComp.buildNode()
        calc.calculate(root: yogaNode, availableWidth: 80, availableHeight: 24)
        let renderNode = boxComp.buildRenderNode(from: yogaNode)

        let output = render(node: renderNode, width: 20, height: 10)
        let lines = output.components(separatedBy: "\n")

        // Line 0: ┌────┐
        XCTAssertTrue(lines[0].hasPrefix("┌"), "Top-left border char")
        XCTAssertTrue(lines[0].hasSuffix("┐"), "Top-right border char")
        // Line 1: │...│
        XCTAssertTrue(lines[1].hasPrefix("│"), "Left border char")
        XCTAssertTrue(lines[1].hasSuffix("│"), "Right border char")
        // Line 2: └────┘
        XCTAssertTrue(lines[2].hasPrefix("└"), "Bottom-left border char")
        XCTAssertTrue(lines[2].hasSuffix("┘"), "Bottom-right border char")

        // Content row contains "hi"
        XCTAssertTrue(lines[1].contains("hi"), "Content should include text")
    }

    func testRenderRoundedBorder() {
        let boxComp = BoxComponent(
            children: [.text(TextComponent("ok"))],
            width: .fixed(6),
            height: .fixed(3),
            border: .rounded
        )
        let yogaNode = boxComp.buildNode()
        calc.calculate(root: yogaNode, availableWidth: 80, availableHeight: 24)
        let renderNode = boxComp.buildRenderNode(from: yogaNode)
        let output = render(node: renderNode, width: 20, height: 10)
        let lines = output.components(separatedBy: "\n")
        XCTAssertTrue(lines[0].hasPrefix("╭"), "Rounded top-left")
        XCTAssertTrue(lines[0].hasSuffix("╮"), "Rounded top-right")
        XCTAssertTrue(lines[2].hasPrefix("╰"), "Rounded bottom-left")
        XCTAssertTrue(lines[2].hasSuffix("╯"), "Rounded bottom-right")
    }

    // MARK: - Colored text

    func testRenderColoredText() {
        let yogaNode = YogaNode()
        yogaNode.text = "red"
        calc.calculate(root: yogaNode, availableWidth: 80, availableHeight: 24)

        let attrs = TextAttributes(color: .red)
        let renderNode = RenderNode.text(
            x: 0, y: 0,
            width: yogaNode.layoutWidth, height: yogaNode.layoutHeight,
            content: "red",
            attributes: attrs
        )

        let output = render(node: renderNode)
        // Should contain ESC sequence
        XCTAssertTrue(output.contains("\u{1B}["), "Colored text should have ANSI escape")
        // Should contain the color code 31 (red)
        XCTAssertTrue(output.contains("31m"), "Red fg color code")
        // Should contain the actual text
        XCTAssertTrue(output.contains("red"), "Text content must be present")
        // Should contain reset
        XCTAssertTrue(output.contains("\u{1B}[0m"), "Should reset attributes after text")
    }

    func testRenderBoldText() {
        let yogaNode = YogaNode()
        yogaNode.text = "bold"
        calc.calculate(root: yogaNode, availableWidth: 80, availableHeight: 24)

        let attrs = TextAttributes(bold: true)
        let renderNode = RenderNode.text(
            x: 0, y: 0,
            width: yogaNode.layoutWidth, height: yogaNode.layoutHeight,
            content: "bold",
            attributes: attrs
        )
        let output = render(node: renderNode)
        XCTAssertTrue(output.contains("\u{1B}[1m"), "Bold should use code 1")
    }

    // MARK: - Multi-line text

    func testRenderMultilineText() {
        let yogaNode = YogaNode()
        yogaNode.text = "line1\nline2"
        calc.calculate(root: yogaNode, availableWidth: 80, availableHeight: 24)
        let renderNode = RenderNode.build(from: yogaNode)
        let output = render(node: renderNode)
        XCTAssertTrue(output.contains("line1"), "First line present")
        XCTAssertTrue(output.contains("line2"), "Second line present")
    }

    // MARK: - Spinner rendering

    func testSpinnerRendersCurrentFrame() {
        let spinner = Spinner(label: "Loading")
        let text = spinner.currentText(frame: 0)
        XCTAssertTrue(text.hasPrefix("⠋"), "First frame is ⠋")
        XCTAssertTrue(text.contains("Loading"), "Label is present")

        let text3 = spinner.currentText(frame: 3)
        XCTAssertTrue(text3.hasPrefix("⠸"), "Fourth frame is ⠸")
    }

    func testSpinnerWrapsFrames() {
        let spinner = Spinner()
        let frameCount = Spinner.brailleFrames.count // 10
        let first = spinner.currentText(frame: 0)
        let wrapped = spinner.currentText(frame: frameCount) // should wrap back to frame 0
        XCTAssertEqual(first, wrapped, "Frame wraps around after all frames")
    }
}
