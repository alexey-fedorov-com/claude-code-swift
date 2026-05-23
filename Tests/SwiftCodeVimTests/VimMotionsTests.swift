import XCTest
@testable import SwiftCodeVim

final class VimMotionsTests: XCTestCase {

    // MARK: - h / l (left / right)

    func testLeft_basic() {
        var buf = VimBuffer(text: "hello", cursor: 4, mode: .normal)
        buf = VimMotions.apply(.left(count: 1), to: buf)
        XCTAssertEqual(buf.cursor, 3)
    }

    func testLeft_clampToLineStart() {
        let buf = VimBuffer(text: "hello", cursor: 0, mode: .normal)
        let result = VimMotions.apply(.left(count: 5), to: buf)
        XCTAssertEqual(result.cursor, 0)
    }

    func testLeft_doesNotCrossNewline() {
        // "ab\ncd" cursor at index 3 ('c'), moving left should not go to newline
        let buf = VimBuffer(text: "ab\ncd", cursor: 3, mode: .normal)
        let result = VimMotions.apply(.left(count: 5), to: buf)
        XCTAssertEqual(result.cursor, 3, "h should not move past the newline onto the previous line")
    }

    func testRight_basic() {
        let buf = VimBuffer(text: "hello", cursor: 0, mode: .normal)
        let result = VimMotions.apply(.right(count: 1), to: buf)
        XCTAssertEqual(result.cursor, 1)
    }

    func testRight_withCount() {
        let buf = VimBuffer(text: "hello world", cursor: 0, mode: .normal)
        let result = VimMotions.apply(.right(count: 5), to: buf)
        XCTAssertEqual(result.cursor, 5)
    }

    func testRight_clampAtLineEnd_normalMode() {
        // "hello" in normal mode — cursor can't go past 'o' (index 4)
        let buf = VimBuffer(text: "hello", cursor: 4, mode: .normal)
        let result = VimMotions.apply(.right(count: 10), to: buf)
        XCTAssertEqual(result.cursor, 4)
    }

    // MARK: - 0 / $ (line start / end)

    func testLineStart() {
        let buf = VimBuffer(text: "hello world", cursor: 6, mode: .normal)
        let result = VimMotions.apply(.lineStart, to: buf)
        XCTAssertEqual(result.cursor, 0)
    }

    func testLineStart_secondLine() {
        // "ab\ncd" — cursor on 'd' (index 4), 0 should go to 'c' (index 3)
        let buf = VimBuffer(text: "ab\ncd", cursor: 4, mode: .normal)
        let result = VimMotions.apply(.lineStart, to: buf)
        XCTAssertEqual(result.cursor, 3)
    }

    func testLineEnd() {
        // "hello" — $ should land on 'o' (index 4)
        let buf = VimBuffer(text: "hello", cursor: 0, mode: .normal)
        let result = VimMotions.apply(.lineEnd, to: buf)
        XCTAssertEqual(result.cursor, 4)
    }

    func testLineEnd_firstLineOfMultiline() {
        // "ab\ncd" — $ from 'a' should land on 'b' (index 1)
        let buf = VimBuffer(text: "ab\ncd", cursor: 0, mode: .normal)
        let result = VimMotions.apply(.lineEnd, to: buf)
        XCTAssertEqual(result.cursor, 1)
    }

    // MARK: - w / b / e (word motions)

    func testWordForward_basic() {
        // "hello world" — w from 'h' should jump to 'w' (index 6)
        let buf = VimBuffer(text: "hello world", cursor: 0)
        let result = VimMotions.apply(.wordForward(count: 1), to: buf)
        XCTAssertEqual(result.cursor, 6)
    }

    func testWordForward_withCount() {
        // "one two three" — 2w from 'o' should jump to 't' of "three" (index 8)
        let buf = VimBuffer(text: "one two three", cursor: 0)
        let result = VimMotions.apply(.wordForward(count: 2), to: buf)
        XCTAssertEqual(result.cursor, 8)
    }

    func testWordBack_basic() {
        // "hello world" — b from 'w' (6) should go to 'h' (0)
        let buf = VimBuffer(text: "hello world", cursor: 6)
        let result = VimMotions.apply(.wordBack(count: 1), to: buf)
        XCTAssertEqual(result.cursor, 0)
    }

    func testWordEnd_basic() {
        // "hello world" — e from 'h' should go to 'o' of "hello" (index 4)
        let buf = VimBuffer(text: "hello world", cursor: 0)
        let result = VimMotions.apply(.wordEnd(count: 1), to: buf)
        XCTAssertEqual(result.cursor, 4)
    }

    // MARK: - gg / G (file top / bottom)

    func testFileStart() {
        let buf = VimBuffer(text: "line1\nline2\nline3", cursor: 12)
        let result = VimMotions.apply(.fileStart, to: buf)
        XCTAssertEqual(result.cursor, 0)
    }

    func testFileEnd() {
        // "line1\nline2\nline3" — G should go to 'l' of "line3" (index 12)
        let buf = VimBuffer(text: "line1\nline2\nline3", cursor: 0)
        let result = VimMotions.apply(.fileEnd, to: buf)
        XCTAssertEqual(result.cursor, 12)
    }

    // MARK: - j / k (up / down)

    func testDown_basic() {
        // "abc\ndefg" — j from 'a' (0) should land on 'd' (4)
        let buf = VimBuffer(text: "abc\ndefg", cursor: 0)
        let result = VimMotions.apply(.down(count: 1), to: buf)
        XCTAssertEqual(result.cursor, 4)
    }

    func testDown_preservesColumn() {
        // "abcd\nef" — j from 'c' (col 2) should land on 'f' (index 6, col 1) because line is shorter
        let buf = VimBuffer(text: "abcd\nef", cursor: 2)
        let result = VimMotions.apply(.down(count: 1), to: buf)
        // 'e' is at 5, 'f' at 6; col 2 would be 'f'
        XCTAssertEqual(result.cursor, 7 - 1) // "ef" ends at index 6
    }

    func testUp_basic() {
        // "abc\ndefg" — k from 'd' (4) should land on 'a' (0)
        let buf = VimBuffer(text: "abc\ndefg", cursor: 4)
        let result = VimMotions.apply(.up(count: 1), to: buf)
        XCTAssertEqual(result.cursor, 0)
    }

    // MARK: - Mode does not change

    func testMotion_doesNotChangeMode() {
        let buf = VimBuffer(text: "hello", cursor: 2, mode: .normal)
        let result = VimMotions.apply(.left(count: 1), to: buf)
        XCTAssertEqual(result.mode, .normal)
    }
}
