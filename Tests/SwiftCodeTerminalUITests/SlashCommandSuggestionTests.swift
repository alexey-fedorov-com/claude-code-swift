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

    func testFilterEmptyPrefixReturnsAll() {
        let matches = SlashCommandSuggestions.filter(prefix: "", commands: registry)
        XCTAssertEqual(matches.count, 4)
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
        let view = SuggestionOverlay(items: Array(items), selectedIndex: 1, width: 50)
        let screen = renderViewToScreen(view, width: 50, height: 6)
        let allText = (0..<6).map { row -> String in
            (0..<50).map { String(screen.cell(at: $0, row: row).character) }.joined()
        }.joined(separator: "\n")
        XCTAssertTrue(allText.contains("> /clear"),
                      "selected row should have '> ' marker on /clear; rendered:\n\(allText)")
    }
}
