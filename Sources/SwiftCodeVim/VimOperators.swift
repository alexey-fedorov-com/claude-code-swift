/// VimOperators — delete, yank, change, paste.
///
/// Each operator is pure: takes a VimBuffer + a range or text-object,
/// returns a new VimBuffer. All mutations go through the default register.

// MARK: - VimOperator

public enum VimOperator: Equatable, Sendable {
    case delete
    case yank
    case change
    case paste(before: Bool)   // p = after cursor, P = before cursor
}

// MARK: - Application

public enum VimOperators {

    // MARK: Range-based operators

    /// Apply `op` over the scalar-index range [start, end] (inclusive).
    public static func apply(
        _ op: VimOperator,
        range: (start: Int, end: Int),
        to buffer: VimBuffer
    ) -> VimBuffer {
        var b = buffer
        let chars = Array(b.text.unicodeScalars)
        let lo = max(0, min(range.start, range.end))
        let hi = min(chars.count - 1, max(range.start, range.end))
        guard lo <= hi else { return b }

        switch op {
        case .delete:
            b.register = String(String.UnicodeScalarView(chars[lo...hi]))
            var result = chars
            result.removeSubrange(lo...hi)
            b.text = String(String.UnicodeScalarView(result))
            b.cursor = max(0, min(lo, result.count - 1))
            b.mode = .normal

        case .yank:
            b.register = String(String.UnicodeScalarView(chars[lo...hi]))
            b.cursor = lo   // vim moves cursor to start of yanked text
            b.mode = .normal

        case .change:
            b.register = String(String.UnicodeScalarView(chars[lo...hi]))
            var result = chars
            result.removeSubrange(lo...hi)
            b.text = String(String.UnicodeScalarView(result))
            b.cursor = max(0, min(lo, result.count))
            b.mode = .insert

        case .paste:
            break   // paste doesn't use a range
        }

        return b
    }

    // MARK: - Line-wise shorthands (dd / yy)

    /// Delete the line containing the cursor (dd).
    public static func deleteLine(in buffer: VimBuffer) -> VimBuffer {
        var b = buffer
        let chars = Array(b.text.unicodeScalars)
        guard !chars.isEmpty else { return b }
        let lineStart = VimMotions.lineStart(of: b.cursor, in: chars)
        var lineEnd = lineStart
        while lineEnd < chars.count && chars[lineEnd] != "\n" { lineEnd += 1 }
        // Include the trailing newline if it exists
        let deleteEnd = lineEnd < chars.count ? lineEnd : lineEnd - 1
        b.register = String(String.UnicodeScalarView(chars[lineStart...deleteEnd]))
        var result = chars
        result.removeSubrange(lineStart...deleteEnd)
        b.text = String(String.UnicodeScalarView(result))
        b.cursor = max(0, min(lineStart, result.count - 1))
        return b
    }

    /// Yank the line containing the cursor (yy).
    public static func yankLine(in buffer: VimBuffer) -> VimBuffer {
        var b = buffer
        let chars = Array(b.text.unicodeScalars)
        guard !chars.isEmpty else { return b }
        let lineStart = VimMotions.lineStart(of: b.cursor, in: chars)
        var lineEnd = lineStart
        while lineEnd < chars.count && chars[lineEnd] != "\n" { lineEnd += 1 }
        let yankEnd = lineEnd < chars.count ? lineEnd : lineEnd - 1
        b.register = String(String.UnicodeScalarView(chars[lineStart...yankEnd]))
        b.cursor = lineStart
        return b
    }

    // MARK: - x (delete character under cursor)

    /// Delete the character under the cursor (x).
    public static func deleteChar(in buffer: VimBuffer) -> VimBuffer {
        var b = buffer
        let chars = Array(b.text.unicodeScalars)
        guard b.cursor < chars.count else { return b }
        b.register = String(chars[b.cursor])
        var result = chars
        result.remove(at: b.cursor)
        b.text = String(String.UnicodeScalarView(result))
        b.cursor = max(0, min(b.cursor, result.count - 1))
        return b
    }

    // MARK: - Paste

    /// Paste register content after the cursor (p) or before (P).
    public static func paste(before: Bool, in buffer: VimBuffer) -> VimBuffer {
        var b = buffer
        guard !b.register.isEmpty else { return b }
        let chars = Array(b.text.unicodeScalars)
        let regChars = Array(b.register.unicodeScalars)
        let insertAt = before ? b.cursor : min(b.cursor + 1, chars.count)
        var result = chars
        result.insert(contentsOf: regChars, at: insertAt)
        b.text = String(String.UnicodeScalarView(result))
        b.cursor = insertAt + regChars.count - 1
        return b
    }

    // MARK: - Text-object operators

    /// Apply operator to a text object.
    public static func apply(
        _ op: VimOperator,
        object: VimTextObject,
        to buffer: VimBuffer
    ) -> VimBuffer {
        switch op {
        case .paste(let before):
            return paste(before: before, in: buffer)
        default:
            guard let range = VimTextObjects.range(for: object, cursor: buffer.cursor, in: buffer.text) else {
                return buffer
            }
            return apply(op, range: range, to: buffer)
        }
    }
}
