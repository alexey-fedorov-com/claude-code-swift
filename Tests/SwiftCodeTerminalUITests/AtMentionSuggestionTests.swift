import XCTest
@testable import SwiftCodeTerminalUI

final class AtMentionSuggestionTests: XCTestCase {
    func testTriggerAtStart() {
        let t = AtMentionSuggestions.detectTrigger(text: "@", cursorOffset: 1)
        XCTAssertEqual(t?.tokenStart, 0)
        XCTAssertEqual(t?.partialPath, "")
    }

    func testTriggerAfterWhitespace() {
        let t = AtMentionSuggestions.detectTrigger(text: "see @src/ma", cursorOffset: 11)
        XCTAssertEqual(t?.tokenStart, 4)
        XCTAssertEqual(t?.partialPath, "src/ma")
    }

    func testNoTriggerInsideWord() {
        XCTAssertNil(AtMentionSuggestions.detectTrigger(text: "foo@bar", cursorOffset: 7))
    }

    func testSplitDirectoryAndPrefix() {
        let split = AtMentionSuggestions.splitDirectoryAndPrefix("src/ma")
        XCTAssertEqual(split.directory, "src")
        XCTAssertEqual(split.prefix, "ma")
        XCTAssertEqual(AtMentionSuggestions.splitDirectoryAndPrefix("foo").directory, "")
        XCTAssertEqual(AtMentionSuggestions.splitDirectoryAndPrefix("foo").prefix, "foo")
        XCTAssertEqual(AtMentionSuggestions.splitDirectoryAndPrefix("src/").directory, "src")
        XCTAssertEqual(AtMentionSuggestions.splitDirectoryAndPrefix("src/").prefix, "")
    }

    func testApplyForFileInsertsRelativePathWithTrailingSpace() {
        let cursor = TextCursor(text: "see @src/ma", offset: 11)
        let updated = AtMentionSuggestions.apply(
            cursor: cursor,
            trigger: AtMentionTrigger(tokenStart: 4, partialPath: "src/ma"),
            selection: PathSuggestion(display: "src/main.swift", isDirectory: false)
        )
        XCTAssertEqual(updated.text, "see @src/main.swift ")
        XCTAssertEqual(updated.offset, 20)
    }

    func testApplyForDirectoryInsertsTrailingSlashNoSpace() {
        let cursor = TextCursor(text: "see @src", offset: 8)
        let updated = AtMentionSuggestions.apply(
            cursor: cursor,
            trigger: AtMentionTrigger(tokenStart: 4, partialPath: "src"),
            selection: PathSuggestion(display: "src", isDirectory: true)
        )
        XCTAssertEqual(updated.text, "see @src/")
        XCTAssertEqual(updated.offset, 9)
    }
}
