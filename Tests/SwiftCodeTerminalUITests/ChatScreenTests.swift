import XCTest
@testable import SwiftCodeTerminalUI

final class ChatScreenTests: XCTestCase {
    private func screenText(_ screen: Screen) -> String {
        (0..<screen.height).map { row -> String in
            (0..<screen.width).map { String(screen.cell(at: $0, row: row).character) }.joined()
        }.joined(separator: "\n")
    }

    func testEmptyChatShowsWelcomeAndPrompt() {
        let view = ChatScreen(state: ChatScreenState(version: "2.1.88"))
        let screen = renderViewToScreen(view, width: 80, height: 30)
        let text = screenText(screen)
        XCTAssertTrue(text.contains("Welcome to Swift Code"))
        XCTAssertTrue(text.contains("╭"))
        XCTAssertTrue(text.contains("> "))
    }

    func testChatWithAssistantMessageShowsBullet() {
        let view = ChatScreen(state: ChatScreenState(
            version: "2.1.88",
            messages: [.assistant("hi from claude")]
        ))
        let screen = renderViewToScreen(view, width: 80, height: 30)
        let text = screenText(screen)
        XCTAssertTrue(text.contains("● hi from claude"),
                      "should show assistant bullet + text; rendered:\n\(text)")
        // No spinner unless loading
        XCTAssertFalse(text.contains("⠋"),
                       "spinner should not render when not loading")
    }

    func testChatLoadingShowsSpinner() {
        let view = ChatScreen(state: ChatScreenState(
            version: "2.1.88",
            messages: [.user("test")],
            isLoading: true,
            spinnerFrame: 0
        ))
        let screen = renderViewToScreen(view, width: 80, height: 30)
        let text = screenText(screen)
        XCTAssertTrue(text.contains(Spinner.dotsFrames[0]),
                      "should show spinner frame 0; rendered:\n\(text)")
        XCTAssertTrue(text.contains("thinking"))
    }
}
