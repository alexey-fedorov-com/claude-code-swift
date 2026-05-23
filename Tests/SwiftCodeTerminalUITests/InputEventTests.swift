import XCTest
@testable import SwiftCodeTerminalUI

final class InputEventTests: XCTestCase {

    private let reader = InputReader()

    // MARK: - Character parsing

    func testParseASCIIChar() {
        let event = reader.parse(bytes: [UInt8(ascii: "a")])
        XCTAssertEqual(event, .character("a"), "Byte 0x61 should parse to .character('a')")
    }

    func testParseUppercaseChar() {
        let event = reader.parse(bytes: [UInt8(ascii: "Z")])
        XCTAssertEqual(event, .character("Z"))
    }

    func testParseDigit() {
        let event = reader.parse(bytes: [UInt8(ascii: "5")])
        XCTAssertEqual(event, .character("5"))
    }

    func testParseSpace() {
        let event = reader.parse(bytes: [UInt8(ascii: " ")])
        XCTAssertEqual(event, .character(" "))
    }

    // MARK: - Control chars

    func testParseCtrlC() {
        // Ctrl+C = 0x03
        let event = reader.parse(bytes: [0x03])
        XCTAssertEqual(event, .controlChar("c"), "0x03 = Ctrl+C")
    }

    func testParseCtrlA() {
        let event = reader.parse(bytes: [0x01])
        XCTAssertEqual(event, .controlChar("a"), "0x01 = Ctrl+A")
    }

    func testParseCtrlZ() {
        let event = reader.parse(bytes: [0x1A])
        XCTAssertEqual(event, .controlChar("z"), "0x1A = Ctrl+Z")
    }

    // MARK: - Special keys

    func testParseBackspace() {
        let event = reader.parse(bytes: [0x7F])
        XCTAssertEqual(event, .backspace, "DEL (0x7F) = backspace")
    }

    func testParseEnter() {
        // Ctrl+M = 0x0D = carriage return (often Enter key)
        let event = reader.parse(bytes: [0x0D])
        XCTAssertEqual(event, .controlChar("m"), "CR = controlChar m")
    }

    func testParseEscape() {
        let event = reader.parse(bytes: [0x1B])
        XCTAssertEqual(event, .escape, "bare ESC = .escape")
    }

    // MARK: - Arrow keys (CSI sequences)

    func testParseArrowUp() {
        // ESC [ A
        let event = reader.parse(bytes: [0x1B, UInt8(ascii: "["), UInt8(ascii: "A")])
        XCTAssertEqual(event, .arrowUp, "ESC[A = arrowUp")
    }

    func testParseArrowDown() {
        let event = reader.parse(bytes: [0x1B, UInt8(ascii: "["), UInt8(ascii: "B")])
        XCTAssertEqual(event, .arrowDown, "ESC[B = arrowDown")
    }

    func testParseArrowRight() {
        let event = reader.parse(bytes: [0x1B, UInt8(ascii: "["), UInt8(ascii: "C")])
        XCTAssertEqual(event, .arrowRight, "ESC[C = arrowRight")
    }

    func testParseArrowLeft() {
        let event = reader.parse(bytes: [0x1B, UInt8(ascii: "["), UInt8(ascii: "D")])
        XCTAssertEqual(event, .arrowLeft, "ESC[D = arrowLeft")
    }

    // MARK: - SS3 arrows (application mode)

    func testParseArrowUpSS3() {
        let event = reader.parse(bytes: [0x1B, UInt8(ascii: "O"), UInt8(ascii: "A")])
        XCTAssertEqual(event, .arrowUp, "ESC O A = arrowUp (SS3)")
    }

    // MARK: - Focus events

    func testParseFocusIn() {
        let event = reader.parse(bytes: [0x1B, UInt8(ascii: "["), UInt8(ascii: "I")])
        XCTAssertEqual(event, .focus, "ESC[I = focus")
    }

    func testParseFocusOut() {
        let event = reader.parse(bytes: [0x1B, UInt8(ascii: "["), UInt8(ascii: "O")])
        XCTAssertEqual(event, .blur, "ESC[O = blur")
    }

    // MARK: - Bracketed paste

    func testParseBracketedPaste() {
        // Build ESC[200~ + payload + ESC[201~
        let open: [UInt8]    = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E]  // ESC[200~
        let payload: [UInt8] = Array("hello paste".utf8)
        let close: [UInt8]   = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E]  // ESC[201~
        let bytes = open + payload + close
        let event = InputReader.parseBracketedPaste(bytes: bytes)
        XCTAssertEqual(event, .paste("hello paste"), "Full bracketed paste sequence")
    }

    func testParseBracketedPasteMultiline() {
        let open: [UInt8]  = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E]
        let payload: [UInt8] = Array("line1\nline2".utf8)
        let close: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E]
        let event = InputReader.parseBracketedPaste(bytes: open + payload + close)
        XCTAssertEqual(event, .paste("line1\nline2"))
    }

    func testParseBracketedPasteEmpty() {
        let open: [UInt8]  = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E]
        let close: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E]
        let event = InputReader.parseBracketedPaste(bytes: open + close)
        XCTAssertEqual(event, .paste(""))
    }

    // MARK: - Function keys

    func testParseFunctionKey1() {
        // F1 via CSI: ESC[11~
        let bytes: [UInt8] = [0x1B, UInt8(ascii: "["), UInt8(ascii: "1"),
                               UInt8(ascii: "1"), UInt8(ascii: "~")]
        let event = reader.parse(bytes: bytes)
        XCTAssertEqual(event, .functionKey(1))
    }

    // MARK: - Shift arrows

    func testParseShiftArrowUp() {
        // ESC[1;2A
        let bytes: [UInt8] = [0x1B, UInt8(ascii: "["), UInt8(ascii: "1"),
                               UInt8(ascii: ";"), UInt8(ascii: "2"), UInt8(ascii: "A")]
        let event = reader.parse(bytes: bytes)
        XCTAssertEqual(event, .shiftArrowUp)
    }

    // MARK: - Unknown sequence

    func testParseUnknownSequence() {
        let bytes: [UInt8] = [0x1B, UInt8(ascii: "["), 0xFF]
        let event = reader.parse(bytes: bytes)
        if case .unknown = event {
            // ok
        } else {
            XCTFail("Unknown CSI sequence should return .unknown, got \(event)")
        }
    }

    // MARK: - Equatability checks

    func testInputEventEquality() {
        XCTAssertEqual(InputEvent.character("a"), InputEvent.character("a"))
        XCTAssertNotEqual(InputEvent.character("a"), InputEvent.character("b"))
        XCTAssertEqual(InputEvent.arrowUp, InputEvent.arrowUp)
        XCTAssertNotEqual(InputEvent.arrowUp, InputEvent.arrowDown)
        XCTAssertEqual(InputEvent.paste("x"), InputEvent.paste("x"))
        XCTAssertNotEqual(InputEvent.paste("x"), InputEvent.paste("y"))
        XCTAssertEqual(InputEvent.resize(width: 80, height: 24), InputEvent.resize(width: 80, height: 24))
        XCTAssertNotEqual(InputEvent.resize(width: 80, height: 24), InputEvent.resize(width: 80, height: 30))
    }
}
