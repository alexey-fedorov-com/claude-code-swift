public struct AtMentionTrigger: Sendable, Equatable {
    public let tokenStart: Int
    public let partialPath: String
    public init(tokenStart: Int, partialPath: String) {
        self.tokenStart = tokenStart; self.partialPath = partialPath
    }
}

public enum AtMentionSuggestions {
    public static func detectTrigger(text: String, cursorOffset: Int) -> AtMentionTrigger? {
        let chars = Array(text)
        guard cursorOffset >= 0 && cursorOffset <= chars.count else { return nil }
        var i = cursorOffset - 1
        while i >= 0 {
            let ch = chars[i]
            if ch == "@" {
                let isStart = (i == 0) || chars[i - 1].isWhitespace
                if !isStart { return nil }
                let partial = String(chars[(i + 1)..<cursorOffset])
                if partial.contains(where: { !isPathChar($0) }) { return nil }
                return AtMentionTrigger(tokenStart: i, partialPath: partial)
            }
            if !isPathChar(ch) { return nil }
            i -= 1
        }
        return nil
    }

    public static func splitDirectoryAndPrefix(_ partial: String) -> (directory: String, prefix: String) {
        if let lastSlash = partial.lastIndex(of: "/") {
            let dir = String(partial[partial.startIndex..<lastSlash])
            let prefix = String(partial[partial.index(after: lastSlash)..<partial.endIndex])
            return (dir, prefix)
        }
        return ("", partial)
    }

    public static func apply(cursor: TextCursor, trigger: AtMentionTrigger,
                             selection: PathSuggestion) -> TextCursor {
        let chars = Array(cursor.text)
        let before = String(chars[0..<trigger.tokenStart])
        let after  = String(chars[cursor.offset..<chars.count])
        let display = selection.display.hasSuffix("/")
            ? String(selection.display.dropLast())
            : selection.display
        let inserted = selection.isDirectory ? "@\(display)/" : "@\(display) "
        let newText = before + inserted + after
        let newOffset = (before + inserted).count
        return TextCursor(text: newText, offset: newOffset)
    }

    private static func isPathChar(_ ch: Character) -> Bool {
        return ch.isLetter || ch.isNumber || ch == "/" || ch == "." || ch == "-" || ch == "_"
    }
}
