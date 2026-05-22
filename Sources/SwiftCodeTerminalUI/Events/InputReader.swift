#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

import Foundation

/// Reads raw bytes from stdin and parses them into InputEvent values.
/// Call `next()` to get the next event (blocks until one is available).
///
/// IMPORTANT: The caller must put the terminal into raw mode before using this.
/// Use `TerminalRawMode.enable()` / `disable()` for that.
public final class InputReader {

    public init() {}

    // MARK: - Public API

    /// Parse a byte sequence into an InputEvent. Useful for testing.
    public func parse(bytes: [UInt8]) -> InputEvent {
        return parseSequence(bytes)
    }

    /// Block and return the next InputEvent from stdin.
    public func next() -> InputEvent? {
        var buf = [UInt8](repeating: 0, count: 256)
        let n = Darwin.read(STDIN_FILENO, &buf, buf.count)
        guard n > 0 else { return nil }
        let bytes = Array(buf.prefix(n))
        return parseSequence(bytes)
    }

    // MARK: - Bracketed paste static helper

    /// Parse a complete bracketed paste sequence from a byte array.
    /// The array must start with ESC[200~ and end with ESC[201~.
    public static func parseBracketedPaste(bytes: [UInt8]) -> InputEvent? {
        let open: [UInt8]  = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E]  // ESC [ 2 0 0 ~
        let close: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E]  // ESC [ 2 0 1 ~
        guard bytes.count >= open.count + close.count else { return nil }
        guard Array(bytes.prefix(open.count)) == open else { return nil }
        guard Array(bytes.suffix(close.count)) == close else { return nil }
        let payload = Array(bytes.dropFirst(open.count).dropLast(close.count))
        if let str = String(bytes: payload, encoding: .utf8) {
            return .paste(str)
        }
        return nil
    }

    // MARK: - Core parser

    func parseSequence(_ bytes: [UInt8]) -> InputEvent {
        guard !bytes.isEmpty else { return .unknown([]) }

        // Bracketed paste: check for full ESC[200~...ESC[201~ sequence
        if bytes.count > 12,
           let event = InputReader.parseBracketedPaste(bytes: bytes) {
            return event
        }

        if bytes[0] == 0x1B {
            let rest = Array(bytes.dropFirst())
            return parseEscapeSequence(rest)
        }

        if bytes.count == 1 {
            return parseSingleByte(bytes[0])
        }

        // Multi-byte UTF-8 character or sequence
        if let str = String(bytes: bytes, encoding: .utf8) {
            if str.unicodeScalars.count == 1, let ch = str.first {
                return .character(ch)
            }
            if let ch = str.first {
                return .character(ch)
            }
        }

        return .unknown(bytes)
    }

    private func parseSingleByte(_ byte: UInt8) -> InputEvent {
        switch byte {
        case 0x00:
            return .controlChar("@")
        case 0x01...0x1A:
            // Ctrl+A (1) through Ctrl+Z (26)
            let offset = byte - 0x01
            let scalar = Unicode.Scalar(UInt32(UInt8(ascii: "a") + offset))!
            let letter = Character(scalar)
            return .controlChar(letter)
        case 0x1B:
            return .escape
        case 0x1C:
            return .controlChar("\\")
        case 0x1D:
            return .controlChar("]")
        case 0x1E:
            return .controlChar("^")
        case 0x1F:
            return .controlChar("_")
        case 0x7F:
            return .backspace
        default:
            let scalar = Unicode.Scalar(UInt32(byte))!
            return .character(Character(scalar))
        }
    }

    private func parseEscapeSequence(_ rest: [UInt8]) -> InputEvent {
        guard !rest.isEmpty else { return .escape }

        if rest[0] == UInt8(ascii: "[") {
            return parseCSI(Array(rest.dropFirst()))
        }

        if rest[0] == UInt8(ascii: "O") {
            return parseSS3(Array(rest.dropFirst()))
        }

        return .escape
    }

    private func parseCSI(_ rest: [UInt8]) -> InputEvent {
        guard !rest.isEmpty else {
            return .unknown([0x1B, UInt8(ascii: "[")])
        }

        let str = String(bytes: rest, encoding: .utf8) ?? ""

        // Focus / blur
        if rest == [UInt8(ascii: "I")] { return .focus }
        if rest == [UInt8(ascii: "O")] { return .blur }

        // Arrow keys
        if rest == [UInt8(ascii: "A")] { return .arrowUp }
        if rest == [UInt8(ascii: "B")] { return .arrowDown }
        if rest == [UInt8(ascii: "C")] { return .arrowRight }
        if rest == [UInt8(ascii: "D")] { return .arrowLeft }

        // Shift+arrows
        if str == "1;2A" { return .shiftArrowUp }
        if str == "1;2B" { return .shiftArrowDown }
        if str == "1;2C" { return .shiftArrowRight }
        if str == "1;2D" { return .shiftArrowLeft }

        // Delete
        if str == "3~" { return .delete }

        // Function keys
        let fnKeys: [(String, Int)] = [
            ("11~", 1), ("12~", 2), ("13~", 3), ("14~", 4), ("15~", 5),
            ("17~", 6), ("18~", 7), ("19~", 8), ("20~", 9), ("21~", 10),
            ("23~", 11), ("24~", 12)
        ]
        for (seq, num) in fnKeys {
            if str == seq { return .functionKey(num) }
        }

        return .unknown([0x1B, UInt8(ascii: "[")] + rest)
    }

    private func parseSS3(_ rest: [UInt8]) -> InputEvent {
        guard rest.count == 1 else {
            return .unknown([0x1B, UInt8(ascii: "O")] + rest)
        }
        switch rest[0] {
        case UInt8(ascii: "A"): return .arrowUp
        case UInt8(ascii: "B"): return .arrowDown
        case UInt8(ascii: "C"): return .arrowRight
        case UInt8(ascii: "D"): return .arrowLeft
        case UInt8(ascii: "P"): return .functionKey(1)
        case UInt8(ascii: "Q"): return .functionKey(2)
        case UInt8(ascii: "R"): return .functionKey(3)
        case UInt8(ascii: "S"): return .functionKey(4)
        default:
            return .unknown([0x1B, UInt8(ascii: "O")] + rest)
        }
    }
}

// MARK: - Terminal raw mode

/// POSIX raw mode enable/disable for interactive use.
public struct TerminalRawMode {
    nonisolated(unsafe) private static var original = termios()
    nonisolated(unsafe) private static var isEnabled = false

    public static func enable() {
        tcgetattr(STDIN_FILENO, &original)
        var raw = original
        cfmakeraw(&raw)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        isEnabled = true
    }

    public static func disable() {
        guard isEnabled else { return }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
        isEnabled = false
    }
}
