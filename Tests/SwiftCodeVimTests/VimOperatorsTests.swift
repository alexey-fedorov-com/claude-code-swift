import XCTest
@testable import SwiftCodeVim

final class VimOperatorsTests: XCTestCase {

    // MARK: - x (delete char under cursor)

    func testDeleteChar_basic() {
        let buf = VimBuffer(text: "hello", cursor: 0)
        let result = VimOperators.deleteChar(in: buf)
        XCTAssertEqual(result.text, "ello")
        XCTAssertEqual(result.register, "h")
        XCTAssertEqual(result.cursor, 0)
    }

    func testDeleteChar_middle() {
        let buf = VimBuffer(text: "hello", cursor: 2)
        let result = VimOperators.deleteChar(in: buf)
        XCTAssertEqual(result.text, "helo")
        XCTAssertEqual(result.register, "l")
    }

    func testDeleteChar_lastChar() {
        let buf = VimBuffer(text: "hi", cursor: 1)
        let result = VimOperators.deleteChar(in: buf)
        XCTAssertEqual(result.text, "h")
        XCTAssertEqual(result.cursor, 0)
    }

    func testDeleteChar_emptyBuffer() {
        let buf = VimBuffer(text: "", cursor: 0)
        let result = VimOperators.deleteChar(in: buf)
        XCTAssertEqual(result.text, "")
    }

    // MARK: - dd (delete line)

    func testDeleteLine_singleLine() {
        let buf = VimBuffer(text: "hello", cursor: 2)
        let result = VimOperators.deleteLine(in: buf)
        XCTAssertEqual(result.text, "")
    }

    func testDeleteLine_firstLine() {
        // "line1\nline2" — dd from line1 should leave "line2"
        let buf = VimBuffer(text: "line1\nline2", cursor: 0)
        let result = VimOperators.deleteLine(in: buf)
        XCTAssertEqual(result.text, "line2")
    }

    func testDeleteLine_secondLine() {
        // "line1\nline2\nline3" — dd from 'line2' cursor at index 6
        let buf = VimBuffer(text: "line1\nline2\nline3", cursor: 6)
        let result = VimOperators.deleteLine(in: buf)
        XCTAssertTrue(result.text.contains("line1"))
        XCTAssertFalse(result.text.contains("line2"))
        XCTAssertTrue(result.text.contains("line3"))
    }

    func testDeleteLine_storesInRegister() {
        let buf = VimBuffer(text: "hello\nworld", cursor: 0)
        let result = VimOperators.deleteLine(in: buf)
        XCTAssertTrue(result.register.contains("hello"))
    }

    // MARK: - yy (yank line)

    func testYankLine_doesNotMutateText() {
        let buf = VimBuffer(text: "hello\nworld", cursor: 0)
        let result = VimOperators.yankLine(in: buf)
        XCTAssertEqual(result.text, "hello\nworld", "yy should not modify the text")
        XCTAssertTrue(result.register.contains("hello"))
    }

    // MARK: - p (paste)

    func testPasteAfter_basic() {
        var buf = VimBuffer(text: "helo", cursor: 1)
        buf.register = "l"
        let result = VimOperators.paste(before: false, in: buf)
        // paste after cursor (after 'e', index 1) → "hello"
        XCTAssertEqual(result.text, "hello")
    }

    func testPasteBefore_basic() {
        var buf = VimBuffer(text: "ello", cursor: 0)
        buf.register = "h"
        let result = VimOperators.paste(before: true, in: buf)
        XCTAssertEqual(result.text, "hello")
    }

    func testPaste_multipleChars() {
        var buf = VimBuffer(text: "world", cursor: 4)
        buf.register = " hello"
        let result = VimOperators.paste(before: false, in: buf)
        XCTAssertEqual(result.text, "world hello")
    }

    func testPaste_emptyRegisterIsNoOp() {
        let buf = VimBuffer(text: "hello", cursor: 2, register: "")
        let result = VimOperators.paste(before: false, in: buf)
        XCTAssertEqual(result.text, "hello")
    }

    // MARK: - Range delete (d + motion)

    func testDeleteRange_basic() {
        let buf = VimBuffer(text: "hello", cursor: 1)
        // delete chars 1-3 inclusive → "ho"
        let result = VimOperators.apply(.delete, range: (1, 3), to: buf)
        XCTAssertEqual(result.text, "ho")
        XCTAssertEqual(result.register, "ell")
        XCTAssertEqual(result.mode, .normal)
    }

    // MARK: - Yank range

    func testYankRange_doesNotMutate() {
        let buf = VimBuffer(text: "hello", cursor: 0)
        let result = VimOperators.apply(.yank, range: (1, 3), to: buf)
        XCTAssertEqual(result.text, "hello")
        XCTAssertEqual(result.register, "ell")
    }

    // MARK: - Change range

    func testChangeRange_entersInsertMode() {
        let buf = VimBuffer(text: "hello world", cursor: 0)
        let result = VimOperators.apply(.change, range: (0, 4), to: buf)
        XCTAssertEqual(result.text, " world")
        XCTAssertEqual(result.mode, .insert)
        XCTAssertEqual(result.register, "hello")
    }

    // MARK: - VimEditor integration (dd / yy via keystrokes)

    func testEditor_dd_deletesLine() {
        let buf = VimBuffer(text: "line1\nline2", cursor: 0, mode: .normal)
        var b = buf
        // First 'd'
        if case .pending(let b1) = VimEditor.process(key: "d", buffer: b) { b = b1 }
        else { XCTFail("expected pending"); return }
        // Second 'd'
        if case .updated(let b2) = VimEditor.process(key: "d", buffer: b) { b = b2 }
        else { XCTFail("expected updated"); return }
        XCTAssertFalse(b.text.contains("line1"))
        XCTAssertTrue(b.text.contains("line2"))
    }

    func testEditor_x_deletesChar() {
        let buf = VimBuffer(text: "hello", cursor: 0, mode: .normal)
        if case .updated(let b) = VimEditor.process(key: "x", buffer: buf) {
            XCTAssertEqual(b.text, "ello")
        } else {
            XCTFail("expected updated")
        }
    }

    func testEditor_i_entersInsertMode() {
        let buf = VimBuffer(text: "hi", cursor: 0, mode: .normal)
        if case .updated(let b) = VimEditor.process(key: "i", buffer: buf) {
            XCTAssertEqual(b.mode, .insert)
        } else {
            XCTFail("expected updated")
        }
    }

    func testEditor_esc_returnsToNormal() {
        let buf = VimBuffer(text: "hi", cursor: 0, mode: .insert)
        if case .updated(let b) = VimEditor.process(key: "Escape", buffer: buf) {
            XCTAssertEqual(b.mode, .normal)
        } else {
            XCTFail("expected updated")
        }
    }
}
