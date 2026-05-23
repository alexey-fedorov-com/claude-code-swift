/// VimMode — modal editing state types.
///
/// Mirrors the vim mode model from `src/utils/vimMode.ts`.

// MARK: - VimMode

public enum VimMode: Equatable, Sendable {
    case normal
    case insert
    case visual
    case visualLine
    case replace
}

// MARK: - VimBuffer

/// Complete vim editor state — all mutations produce a new value.
public struct VimBuffer: Equatable, Sendable {
    /// Full text of the buffer.
    public var text: String
    /// Cursor position as a Unicode scalar offset (character index).
    public var cursor: Int
    /// Current modal state.
    public var mode: VimMode
    /// Accumulated pending key input (e.g. "2" before "w", or "d" waiting for motion).
    public var pending: String
    /// Named default register — holds the last deleted/yanked text.
    public var register: String
    /// Visual mode anchor (start of selection when in .visual/.visualLine).
    public var visualAnchor: Int?

    public init(
        text: String = "",
        cursor: Int = 0,
        mode: VimMode = .normal,
        pending: String = "",
        register: String = "",
        visualAnchor: Int? = nil
    ) {
        self.text = text
        self.cursor = max(0, cursor)
        self.mode = mode
        self.pending = pending
        self.register = register
        self.visualAnchor = visualAnchor
    }
}

// MARK: - Mode transitions

extension VimBuffer {
    /// Enter insert mode at the cursor.
    public func enterInsert() -> VimBuffer {
        var b = self; b.mode = .insert; b.pending = ""; return b
    }

    /// Enter insert mode one character after the cursor (vim `a`).
    public func enterAppend() -> VimBuffer {
        var b = self
        b.mode = .insert
        b.pending = ""
        let chars = Array(b.text.unicodeScalars)
        if b.cursor < chars.count { b.cursor += 1 }
        return b
    }

    /// Open a new line below and enter insert mode (vim `o`).
    public func openLineBelow() -> VimBuffer {
        var b = self
        let chars = Array(b.text.unicodeScalars)
        // Find end of current line
        var pos = b.cursor
        while pos < chars.count && chars[pos] != "\n" { pos += 1 }
        // Insert newline after line end
        var scalars = chars
        scalars.insert("\n", at: pos + 1)
        b.text = String(String.UnicodeScalarView(scalars))
        b.cursor = pos + 1
        b.mode = .insert
        b.pending = ""
        return b
    }

    /// Enter visual mode.
    public func enterVisual() -> VimBuffer {
        var b = self; b.mode = .visual; b.visualAnchor = b.cursor; b.pending = ""; return b
    }

    /// Enter visual-line mode.
    public func enterVisualLine() -> VimBuffer {
        var b = self; b.mode = .visualLine; b.visualAnchor = b.cursor; b.pending = ""; return b
    }

    /// Return to normal mode.
    public func enterNormal() -> VimBuffer {
        var b = self; b.mode = .normal; b.pending = ""; b.visualAnchor = nil; return b
    }
}
