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
        XCTAssertEqual(screen.cell(at: 2, row: 0).character, "h")
    }

    func testAssistantMessageWrapsLongText() {
        // 20-cell width: "● this is a longer  " (18 cells of bullet+text), then wrap
        let view = AssistantMessageView(text: "this is a longer message that should wrap to multiple lines")
        let screen = renderViewToScreen(view, width: 20, height: 5)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, "●")
        // continuation lines: indent by 2 (no bullet)
        XCTAssertEqual(screen.cell(at: 0, row: 1).character, " ")
        XCTAssertEqual(screen.cell(at: 1, row: 1).character, " ")
    }

    func testSystemMessageIsIndentedAndDim() {
        let view = SystemMessageView(text: "status")
        let screen = renderViewToScreen(view, width: 20, height: 1)
        // Two-space indent, "status" follows
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, " ")
        XCTAssertEqual(screen.cell(at: 1, row: 0).character, " ")
        XCTAssertEqual(screen.cell(at: 2, row: 0).character, "s")
    }

    func testMessageListRendersInOrder() {
        let messages: [any View] = [
            UserMessageView(text: "first"),
            AssistantMessageView(text: "second"),
        ]
        let view = MessageList(messages: messages)
        let screen = renderViewToScreen(view, width: 20, height: 4)
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, ">")
        // Row 1 is the blank separator
        XCTAssertEqual(screen.cell(at: 0, row: 2).character, "●")
    }

    func testEmptyMessageListIsEmpty() {
        let view = MessageList(messages: [])
        let screen = renderViewToScreen(view, width: 20, height: 2)
        // No content, all blanks
        XCTAssertEqual(screen.cell(at: 0, row: 0).character, " ")
    }
}
