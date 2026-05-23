/// VimTextObjects — inner/around word and delimiter text objects.
///
/// Each function returns a (start, end) range (inclusive) in the buffer's
/// scalar index space, or nil if the object can't be found.

// MARK: - VimTextObject

public enum VimTextObject: Equatable, Sendable {
    case innerWord              // iw
    case aroundWord             // aw
    case innerQuoteDouble       // i"
    case aroundQuoteDouble      // a"
    case innerQuoteSingle       // i'
    case aroundQuoteSingle      // a'
    case innerParen             // i(  / i)
    case aroundParen            // a(  / a)
    case innerBracket           // i[  / i]
    case aroundBracket          // a[  / a]
    case innerBrace             // i{  / i}
    case aroundBrace            // a{  / a}
}

// MARK: - Resolution

public enum VimTextObjects {
    /// Returns the (start, end) inclusive scalar-index range for `object`
    /// relative to `cursor` in `text`, or `nil` if not applicable.
    public static func range(
        for object: VimTextObject,
        cursor: Int,
        in text: String
    ) -> (start: Int, end: Int)? {
        let chars = Array(text.unicodeScalars)
        switch object {
        case .innerWord:
            return innerWord(at: cursor, in: chars)
        case .aroundWord:
            return aroundWord(at: cursor, in: chars)
        case .innerQuoteDouble:
            return innerQuote("\"", at: cursor, in: chars)
        case .aroundQuoteDouble:
            return aroundQuote("\"", at: cursor, in: chars)
        case .innerQuoteSingle:
            return innerQuote("'", at: cursor, in: chars)
        case .aroundQuoteSingle:
            return aroundQuote("'", at: cursor, in: chars)
        case .innerParen:
            return innerDelimiter(open: "(", close: ")", at: cursor, in: chars)
        case .aroundParen:
            return aroundDelimiter(open: "(", close: ")", at: cursor, in: chars)
        case .innerBracket:
            return innerDelimiter(open: "[", close: "]", at: cursor, in: chars)
        case .aroundBracket:
            return aroundDelimiter(open: "[", close: "]", at: cursor, in: chars)
        case .innerBrace:
            return innerDelimiter(open: "{", close: "}", at: cursor, in: chars)
        case .aroundBrace:
            return aroundDelimiter(open: "{", close: "}", at: cursor, in: chars)
        }
    }

    // MARK: - Word objects

    private static func innerWord(at pos: Int, in chars: [Unicode.Scalar]) -> (Int, Int)? {
        guard pos < chars.count else { return nil }
        if VimMotions.isWhitespace(chars[pos]) { return whitespanRun(at: pos, in: chars) }
        var start = pos
        var end = pos
        while start > 0 && VimMotions.isWordChar(chars[start - 1]) { start -= 1 }
        while end + 1 < chars.count && VimMotions.isWordChar(chars[end + 1]) { end += 1 }
        if VimMotions.isWordChar(chars[pos]) { return (start, end) }
        // Non-word, non-space run
        var s = pos, e = pos
        while s > 0 && !VimMotions.isWordChar(chars[s - 1]) && !VimMotions.isWhitespace(chars[s - 1]) { s -= 1 }
        while e + 1 < chars.count && !VimMotions.isWordChar(chars[e + 1]) && !VimMotions.isWhitespace(chars[e + 1]) { e += 1 }
        return (s, e)
    }

    private static func aroundWord(at pos: Int, in chars: [Unicode.Scalar]) -> (Int, Int)? {
        guard let (start, end) = innerWord(at: pos, in: chars) else { return nil }
        // Include trailing whitespace if present, else leading whitespace
        var e = end
        while e + 1 < chars.count && VimMotions.isWhitespace(chars[e + 1]) { e += 1 }
        if e > end { return (start, e) }
        var s = start
        while s > 0 && VimMotions.isWhitespace(chars[s - 1]) { s -= 1 }
        return (s, end)
    }

    private static func whitespanRun(at pos: Int, in chars: [Unicode.Scalar]) -> (Int, Int) {
        var s = pos, e = pos
        while s > 0 && VimMotions.isWhitespace(chars[s - 1]) { s -= 1 }
        while e + 1 < chars.count && VimMotions.isWhitespace(chars[e + 1]) { e += 1 }
        return (s, e)
    }

    // MARK: - Quote objects

    private static func innerQuote(_ q: Unicode.Scalar, at pos: Int, in chars: [Unicode.Scalar]) -> (Int, Int)? {
        // Find the quote pair enclosing pos on the current line
        guard let (open, close) = quotePair(q, at: pos, in: chars) else { return nil }
        guard close > open + 1 else { return nil }
        return (open + 1, close - 1)
    }

    private static func aroundQuote(_ q: Unicode.Scalar, at pos: Int, in chars: [Unicode.Scalar]) -> (Int, Int)? {
        guard let (open, close) = quotePair(q, at: pos, in: chars) else { return nil }
        return (open, close)
    }

    private static func quotePair(
        _ q: Unicode.Scalar, at pos: Int, in chars: [Unicode.Scalar]
    ) -> (Int, Int)? {
        // Search left for opening quote on same line
        var left = pos
        while left >= 0 {
            if chars[left] == "\n" { break }
            if chars[left] == q {
                // Found potential open; search right for close
                var right = left + 1
                while right < chars.count {
                    if chars[right] == "\n" { break }
                    if chars[right] == q { return (left, right) }
                    right += 1
                }
            }
            if left == 0 { break }
            left -= 1
        }
        return nil
    }

    // MARK: - Delimiter objects

    private static func innerDelimiter(
        open: Unicode.Scalar, close: Unicode.Scalar, at pos: Int, in chars: [Unicode.Scalar]
    ) -> (Int, Int)? {
        guard let (o, c) = delimiterPair(open: open, close: close, at: pos, in: chars) else { return nil }
        guard c > o + 1 else { return nil }
        return (o + 1, c - 1)
    }

    private static func aroundDelimiter(
        open: Unicode.Scalar, close: Unicode.Scalar, at pos: Int, in chars: [Unicode.Scalar]
    ) -> (Int, Int)? {
        guard let (o, c) = delimiterPair(open: open, close: close, at: pos, in: chars) else { return nil }
        return (o, c)
    }

    private static func delimiterPair(
        open: Unicode.Scalar, close: Unicode.Scalar, at pos: Int, in chars: [Unicode.Scalar]
    ) -> (Int, Int)? {
        // Walk left to find matching open (respecting nesting)
        var depth = 0
        var left = pos
        while left >= 0 {
            if chars[left] == close { depth += 1 }
            if chars[left] == open {
                if depth == 0 {
                    // Found open — now find matching close
                    var right = left + 1
                    var d = 1
                    while right < chars.count {
                        if chars[right] == open { d += 1 }
                        if chars[right] == close {
                            d -= 1
                            if d == 0 { return (left, right) }
                        }
                        right += 1
                    }
                    return nil
                }
                depth -= 1
            }
            if left == 0 { break }
            left -= 1
        }
        return nil
    }
}
