// MARK: - CommandSuggestion

public struct CommandSuggestion: Sendable, Equatable {
    public let name: String
    public let description: String
    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

// MARK: - SlashTrigger

public struct SlashTrigger: Sendable, Equatable {
    public let tokenStart: Int
    public let prefix: String
    public init(tokenStart: Int, prefix: String) {
        self.tokenStart = tokenStart
        self.prefix = prefix
    }
}

// MARK: - SlashCommandSuggestions

public enum SlashCommandSuggestions {

    /// Detect whether the cursor is positioned right after a "/" token that
    /// is at the start of the line or preceded by whitespace.
    /// Returns a `SlashTrigger` with the slash's index and the typed prefix, or
    /// `nil` when the cursor is not in a slash-command position.
    public static func detectTrigger(text: String, cursorOffset: Int) -> SlashTrigger? {
        let chars = Array(text)
        guard cursorOffset >= 0 && cursorOffset <= chars.count else { return nil }
        var i = cursorOffset - 1
        while i >= 0 {
            let ch = chars[i]
            if ch == "/" {
                // The slash must appear at start of line or after whitespace
                let isStart = (i == 0) || chars[i - 1].isWhitespace
                if !isStart { return nil }
                let prefixChars = Array(chars[(i + 1)..<cursorOffset])
                // All chars between "/" and cursor must be valid command chars
                if prefixChars.contains(where: { !isCommandChar($0) }) { return nil }
                return SlashTrigger(tokenStart: i, prefix: String(prefixChars))
            }
            // If we hit a non-command char before finding "/", bail out
            if !isCommandChar(ch) { return nil }
            i -= 1
        }
        return nil
    }

    /// Filter the command list to those whose name starts with `prefix`.
    /// If `prefix` is empty, all commands are returned.
    public static func filter(prefix: String, commands: [CommandSuggestion]) -> [CommandSuggestion] {
        guard !prefix.isEmpty else { return commands }
        let lower = prefix.lowercased()
        return commands.filter { $0.name.lowercased().hasPrefix(lower) }
    }

    /// Replace the slash token in `cursor` with the chosen `selection`, followed
    /// by a trailing space. Returns an updated `TextCursor` with the new text
    /// and cursor positioned after the inserted text.
    public static func apply(cursor: TextCursor,
                             trigger: SlashTrigger,
                             selection: CommandSuggestion) -> TextCursor {
        let chars = Array(cursor.text)
        let before = String(chars[0..<trigger.tokenStart])
        let after  = String(chars[cursor.offset..<chars.count])
        let inserted = "/\(selection.name) "
        let newText = before + inserted + after
        let newOffset = (before + inserted).count
        return TextCursor(text: newText, offset: newOffset)
    }

    // MARK: - Private

    private static func isCommandChar(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == ":" || ch == "-" || ch == "_"
    }
}
