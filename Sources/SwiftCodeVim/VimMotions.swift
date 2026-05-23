/// VimMotions — cursor movement in a VimBuffer.
///
/// Every motion is pure: takes a VimBuffer, returns a new VimBuffer with
/// the cursor repositioned. No I/O, no mutation.

// MARK: - VimMotion

public enum VimMotion: Equatable, Sendable {
    case left(count: Int)
    case right(count: Int)
    case up(count: Int)
    case down(count: Int)
    case wordForward(count: Int)   // w
    case wordBack(count: Int)      // b
    case wordEnd(count: Int)       // e
    case lineStart                 // 0
    case lineEnd                   // $
    case fileStart                 // gg
    case fileEnd                   // G
    case findChar(Character, count: Int)        // f<c>
    case findCharBack(Character, count: Int)    // F<c>
    case tillChar(Character, count: Int)        // t<c>
    case tillCharBack(Character, count: Int)    // T<c>
}

// MARK: - Motion application

public enum VimMotions {
    // MARK: Public API

    /// Apply a motion to `buffer`, returning the updated buffer.
    public static func apply(_ motion: VimMotion, to buffer: VimBuffer) -> VimBuffer {
        var b = buffer
        let chars = Array(b.text.unicodeScalars)
        let len = chars.count

        switch motion {
        case .left(let count):
            b.cursor = clampedLeft(from: b.cursor, count: count, in: chars)

        case .right(let count):
            b.cursor = clampedRight(from: b.cursor, count: count, in: chars, stopBeforeNewline: b.mode == .normal)

        case .up(let count):
            b.cursor = moveUp(from: b.cursor, count: count, in: chars)

        case .down(let count):
            b.cursor = moveDown(from: b.cursor, count: count, in: chars)

        case .wordForward(let count):
            var pos = b.cursor
            for _ in 0..<max(1, count) { pos = nextWordStart(from: pos, in: chars) }
            b.cursor = min(pos, max(0, len - 1))

        case .wordBack(let count):
            var pos = b.cursor
            for _ in 0..<max(1, count) { pos = prevWordStart(from: pos, in: chars) }
            b.cursor = max(0, pos)

        case .wordEnd(let count):
            var pos = b.cursor
            for _ in 0..<max(1, count) { pos = nextWordEnd(from: pos, in: chars) }
            b.cursor = min(pos, max(0, len - 1))

        case .lineStart:
            b.cursor = lineStart(of: b.cursor, in: chars)

        case .lineEnd:
            b.cursor = lineEnd(of: b.cursor, in: chars, stopBeforeNewline: b.mode == .normal)

        case .fileStart:
            b.cursor = 0

        case .fileEnd:
            // G → first char of last line
            b.cursor = lastLineStart(in: chars)

        case .findChar(let ch, let count):
            var pos = b.cursor
            for _ in 0..<max(1, count) {
                if let next = findForward(ch, from: pos + 1, in: chars) { pos = next }
            }
            b.cursor = pos

        case .findCharBack(let ch, let count):
            var pos = b.cursor
            for _ in 0..<max(1, count) {
                if let prev = findBackward(ch, from: pos - 1, in: chars) { pos = prev }
            }
            b.cursor = pos

        case .tillChar(let ch, let count):
            var pos = b.cursor
            for _ in 0..<max(1, count) {
                if let next = findForward(ch, from: pos + 1, in: chars) { pos = next - 1 }
            }
            b.cursor = max(0, pos)

        case .tillCharBack(let ch, let count):
            var pos = b.cursor
            for _ in 0..<max(1, count) {
                if let prev = findBackward(ch, from: pos - 1, in: chars) { pos = prev + 1 }
            }
            b.cursor = min(pos, max(0, len - 1))
        }

        return b
    }

    // MARK: - Helpers (package-internal for operator use)

    static func lineStart(of pos: Int, in chars: [Unicode.Scalar]) -> Int {
        var i = pos
        while i > 0 && chars[i - 1] != "\n" { i -= 1 }
        return i
    }

    static func lineEnd(of pos: Int, in chars: [Unicode.Scalar], stopBeforeNewline: Bool) -> Int {
        var i = pos
        while i < chars.count && chars[i] != "\n" { i += 1 }
        if stopBeforeNewline && i > pos { return i - 1 }
        return min(i, chars.count - 1)
    }

    static func lastLineStart(in chars: [Unicode.Scalar]) -> Int {
        guard !chars.isEmpty else { return 0 }
        var i = chars.count - 1
        // Skip trailing newline if it's the very last character
        if chars[i] == "\n" && i > 0 { i -= 1 }
        while i > 0 && chars[i - 1] != "\n" { i -= 1 }
        return i
    }

    static func nextWordStart(from pos: Int, in chars: [Unicode.Scalar]) -> Int {
        var i = pos
        let len = chars.count
        guard i < len else { return len }
        // Skip current word chars
        if isWordChar(chars[i]) {
            while i < len && isWordChar(chars[i]) { i += 1 }
        } else if !isWhitespace(chars[i]) {
            while i < len && !isWordChar(chars[i]) && !isWhitespace(chars[i]) { i += 1 }
        }
        // Skip whitespace
        while i < len && isWhitespace(chars[i]) { i += 1 }
        return i
    }

    static func prevWordStart(from pos: Int, in chars: [Unicode.Scalar]) -> Int {
        guard pos > 0 else { return 0 }
        var i = pos - 1
        // Skip trailing whitespace
        while i > 0 && isWhitespace(chars[i]) { i -= 1 }
        if isWordChar(chars[i]) {
            while i > 0 && isWordChar(chars[i - 1]) { i -= 1 }
        } else {
            while i > 0 && !isWordChar(chars[i - 1]) && !isWhitespace(chars[i - 1]) { i -= 1 }
        }
        return i
    }

    static func nextWordEnd(from pos: Int, in chars: [Unicode.Scalar]) -> Int {
        var i = pos + 1
        let len = chars.count
        guard i < len else { return max(0, len - 1) }
        // Skip whitespace
        while i < len && isWhitespace(chars[i]) { i += 1 }
        // Move to end of this word
        if isWordChar(chars[i]) {
            while i + 1 < len && isWordChar(chars[i + 1]) { i += 1 }
        } else {
            while i + 1 < len && !isWordChar(chars[i + 1]) && !isWhitespace(chars[i + 1]) { i += 1 }
        }
        return i
    }

    static func findForward(_ ch: Character, from pos: Int, in chars: [Unicode.Scalar]) -> Int? {
        let target = Unicode.Scalar(String(ch))!
        for i in pos..<chars.count where chars[i] == target { return i }
        return nil
    }

    static func findBackward(_ ch: Character, from pos: Int, in chars: [Unicode.Scalar]) -> Int? {
        let target = Unicode.Scalar(String(ch))!
        var i = pos
        while i >= 0 {
            if chars[i] == target { return i }
            if i == 0 { break }
            i -= 1
        }
        return nil
    }

    // MARK: - Private helpers

    private static func clampedLeft(from pos: Int, count: Int, in chars: [Unicode.Scalar]) -> Int {
        let lineBegin = lineStart(of: pos, in: chars)
        return max(lineBegin, pos - max(1, count))
    }

    private static func clampedRight(
        from pos: Int, count: Int, in chars: [Unicode.Scalar], stopBeforeNewline: Bool
    ) -> Int {
        let len = chars.count
        var target = pos + max(1, count)
        // Don't go past the current line end in normal mode
        if stopBeforeNewline {
            var lineEnd = pos
            while lineEnd < len && chars[lineEnd] != "\n" { lineEnd += 1 }
            if lineEnd > 0 { lineEnd -= 1 } // stay before newline
            target = min(target, lineEnd)
        }
        return min(target, max(0, len - 1))
    }

    private static func moveUp(from pos: Int, count: Int, in chars: [Unicode.Scalar]) -> Int {
        let col = pos - lineStart(of: pos, in: chars)
        var lineBegin = lineStart(of: pos, in: chars)
        for _ in 0..<max(1, count) {
            guard lineBegin > 0 else { return min(col, lineEnd(of: 0, in: chars, stopBeforeNewline: true)) }
            lineBegin = lineStart(of: lineBegin - 1, in: chars)
        }
        let lineLen = lineEnd(of: lineBegin, in: chars, stopBeforeNewline: false) - lineBegin
        return lineBegin + min(col, lineLen)
    }

    private static func moveDown(from pos: Int, count: Int, in chars: [Unicode.Scalar]) -> Int {
        let col = pos - lineStart(of: pos, in: chars)
        var lineBegin = lineStart(of: pos, in: chars)
        for _ in 0..<max(1, count) {
            // Find newline at end of current line
            var nl = lineBegin
            while nl < chars.count && chars[nl] != "\n" { nl += 1 }
            guard nl < chars.count else { return pos } // already last line
            lineBegin = nl + 1
        }
        let lineLen = lineEnd(of: lineBegin, in: chars, stopBeforeNewline: false) - lineBegin
        return min(lineBegin + min(col, lineLen), chars.count - 1)
    }

    static func isWordChar(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (v >= 65 && v <= 90)   // A-Z
            || (v >= 97 && v <= 122)  // a-z
            || (v >= 48 && v <= 57)   // 0-9
            || v == 95                // _
    }

    static func isWhitespace(_ s: Unicode.Scalar) -> Bool {
        s == " " || s == "\t" || s == "\n" || s == "\r"
    }
}
