/// VimEditor — high-level command dispatch.
///
/// Accepts raw key sequences, maintains pending-operator state, and
/// dispatches to VimMotions / VimOperators. All state lives in VimBuffer
/// so the editor itself is a stateless transformer.

// MARK: - VimCommand

/// The result of interpreting a key press in the current buffer state.
public enum VimCommandResult: Sendable {
    /// The command completed; here is the new buffer state.
    case updated(VimBuffer)
    /// The key was accumulated into `pending` — more keys needed.
    case pending(VimBuffer)
    /// The key was not recognized in the current mode.
    case unhandled
}

// MARK: - VimEditor

public enum VimEditor {

    /// Process a single key string (e.g. "h", "2", "d", "Esc", "Enter")
    /// in the context of `buffer`. Returns the next buffer state.
    public static func process(key: String, buffer: VimBuffer) -> VimCommandResult {
        switch buffer.mode {
        case .insert:
            return processInsert(key: key, buffer: buffer)
        case .normal:
            return processNormal(key: key, buffer: buffer)
        case .visual, .visualLine:
            return processVisual(key: key, buffer: buffer)
        case .replace:
            return processReplace(key: key, buffer: buffer)
        }
    }

    // MARK: - Insert mode

    private static func processInsert(key: String, buffer: VimBuffer) -> VimCommandResult {
        switch key {
        case "Escape", "Esc":
            var b = buffer.enterNormal()
            // Move cursor one left (standard vim behaviour)
            let chars = Array(b.text.unicodeScalars)
            if b.cursor > 0 {
                let lineBegin = VimMotions.lineStart(of: b.cursor, in: chars)
                if b.cursor > lineBegin { b.cursor -= 1 }
            }
            return .updated(b)
        case "Backspace":
            var b = buffer
            let chars = Array(b.text.unicodeScalars)
            guard b.cursor > 0 else { return .updated(b) }
            var result = chars
            result.remove(at: b.cursor - 1)
            b.text = String(String.UnicodeScalarView(result))
            b.cursor -= 1
            return .updated(b)
        default:
            // Printable character — insert at cursor
            guard key.count == 1 else { return .unhandled }
            var b = buffer
            var chars = Array(b.text.unicodeScalars)
            let scalar = key.unicodeScalars.first!
            chars.insert(scalar, at: b.cursor)
            b.text = String(String.UnicodeScalarView(chars))
            b.cursor += 1
            return .updated(b)
        }
    }

    // MARK: - Normal mode

    private static func processNormal(key: String, buffer: VimBuffer) -> VimCommandResult {
        let pending = buffer.pending

        // --- Count accumulation ---
        if let digit = Int(key), !(key == "0" && pending.isEmpty) {
            var b = buffer; b.pending += key; return .pending(b)
        }

        let count = pendingCount(from: pending)

        // --- Mode transitions ---
        switch key {
        case "i":
            var b = buffer; b.pending = ""; return .updated(b.enterInsert())
        case "a":
            var b = buffer; b.pending = ""; return .updated(b.enterAppend())
        case "o":
            var b = buffer; b.pending = ""; return .updated(b.openLineBelow())
        case "v":
            var b = buffer; b.pending = ""; return .updated(b.enterVisual())
        case "V":
            var b = buffer; b.pending = ""; return .updated(b.enterVisualLine())
        case "Escape", "Esc":
            var b = buffer; b.pending = ""; return .updated(b)

        // --- Motion keys ---
        case "h":
            return .updated(applyMotion(.left(count: count), to: buffer))
        case "l":
            return .updated(applyMotion(.right(count: count), to: buffer))
        case "k":
            return .updated(applyMotion(.up(count: count), to: buffer))
        case "j":
            return .updated(applyMotion(.down(count: count), to: buffer))
        case "w":
            return .updated(applyMotion(.wordForward(count: count), to: buffer))
        case "b":
            return .updated(applyMotion(.wordBack(count: count), to: buffer))
        case "e":
            return .updated(applyMotion(.wordEnd(count: count), to: buffer))
        case "0":
            return .updated(applyMotion(.lineStart, to: buffer))
        case "$":
            return .updated(applyMotion(.lineEnd, to: buffer))
        case "g":
            if pending.hasSuffix("g") {
                return .updated(applyMotion(.fileStart, to: buffer))
            } else {
                var b = buffer; b.pending = "g"; return .pending(b)
            }
        case "G":
            return .updated(applyMotion(.fileEnd, to: buffer))

        // --- Operator keys ---
        case "x":
            return .updated(VimOperators.deleteChar(in: buffer).withPendingCleared())
        case "p":
            return .updated(VimOperators.paste(before: false, in: buffer).withPendingCleared())
        case "P":
            return .updated(VimOperators.paste(before: true, in: buffer).withPendingCleared())

        // --- Operator + motion dispatch (d / y / c) ---
        case "d":
            if pending.hasSuffix("d") {
                // dd — delete line
                var result = VimOperators.deleteLine(in: buffer)
                result.pending = ""
                return .updated(result)
            } else {
                var b = buffer; b.pending = pending + "d"; return .pending(b)
            }
        case "y":
            if pending.hasSuffix("y") {
                var result = VimOperators.yankLine(in: buffer)
                result.pending = ""
                return .updated(result)
            } else {
                var b = buffer; b.pending = pending + "y"; return .pending(b)
            }
        case "c":
            if pending.hasSuffix("c") {
                // cc — change line
                var result = VimOperators.deleteLine(in: buffer)
                result.mode = .insert
                result.pending = ""
                return .updated(result)
            } else {
                var b = buffer; b.pending = pending + "c"; return .pending(b)
            }

        default:
            // Try operator + motion pairs already accumulated in pending
            if let op = pendingOperator(from: pending) {
                if let motion = motionFromKey(key, count: count) {
                    return operatorMotion(op, motion: motion, buffer: buffer)
                }
            }
            return .unhandled
        }
    }

    // MARK: - Visual mode

    private static func processVisual(key: String, buffer: VimBuffer) -> VimCommandResult {
        switch key {
        case "Escape", "Esc":
            return .updated(buffer.enterNormal())
        case "d", "x":
            guard let anchor = buffer.visualAnchor else { return .updated(buffer.enterNormal()) }
            let lo = min(anchor, buffer.cursor)
            let hi = max(anchor, buffer.cursor)
            var result = VimOperators.apply(.delete, range: (lo, hi), to: buffer)
            result.mode = .normal
            result.visualAnchor = nil
            result.pending = ""
            return .updated(result)
        case "y":
            guard let anchor = buffer.visualAnchor else { return .updated(buffer.enterNormal()) }
            let lo = min(anchor, buffer.cursor)
            let hi = max(anchor, buffer.cursor)
            var result = VimOperators.apply(.yank, range: (lo, hi), to: buffer)
            result.mode = .normal
            result.visualAnchor = nil
            result.pending = ""
            return .updated(result)
        case "h":
            return .updated(applyMotion(.left(count: 1), to: buffer))
        case "l":
            return .updated(applyMotion(.right(count: 1), to: buffer))
        case "j":
            return .updated(applyMotion(.down(count: 1), to: buffer))
        case "k":
            return .updated(applyMotion(.up(count: 1), to: buffer))
        case "w":
            return .updated(applyMotion(.wordForward(count: 1), to: buffer))
        case "b":
            return .updated(applyMotion(.wordBack(count: 1), to: buffer))
        default:
            return .unhandled
        }
    }

    // MARK: - Replace mode

    private static func processReplace(key: String, buffer: VimBuffer) -> VimCommandResult {
        switch key {
        case "Escape", "Esc":
            return .updated(buffer.enterNormal())
        default:
            guard key.count == 1 else { return .unhandled }
            var b = buffer
            var chars = Array(b.text.unicodeScalars)
            guard b.cursor < chars.count else { return .unhandled }
            chars[b.cursor] = key.unicodeScalars.first!
            b.text = String(String.UnicodeScalarView(chars))
            b.mode = .normal
            return .updated(b)
        }
    }

    // MARK: - Private helpers

    private static func applyMotion(_ motion: VimMotion, to buffer: VimBuffer) -> VimBuffer {
        var b = VimMotions.apply(motion, to: buffer)
        b.pending = ""
        return b
    }

    private static func pendingCount(from pending: String) -> Int {
        // Strip any trailing operator char
        let digits = pending.prefix(while: { $0.isNumber })
        return Int(digits) ?? 1
    }

    private static func pendingOperator(from pending: String) -> VimOperator? {
        if pending.hasSuffix("d") { return .delete }
        if pending.hasSuffix("y") { return .yank }
        if pending.hasSuffix("c") { return .change }
        return nil
    }

    private static func motionFromKey(_ key: String, count: Int) -> VimMotion? {
        switch key {
        case "h": return .left(count: count)
        case "l": return .right(count: count)
        case "j": return .down(count: count)
        case "k": return .up(count: count)
        case "w": return .wordForward(count: count)
        case "b": return .wordBack(count: count)
        case "e": return .wordEnd(count: count)
        case "0": return .lineStart
        case "$": return .lineEnd
        case "G": return .fileEnd
        default: return nil
        }
    }

    private static func operatorMotion(
        _ op: VimOperator, motion: VimMotion, buffer: VimBuffer
    ) -> VimCommandResult {
        // Get cursor position after motion
        let afterMotion = VimMotions.apply(motion, to: buffer)
        let lo = min(buffer.cursor, afterMotion.cursor)
        let hi = max(buffer.cursor, afterMotion.cursor)
        var result = VimOperators.apply(op, range: (lo, hi), to: buffer)
        result.pending = ""
        return .updated(result)
    }
}

// MARK: - Convenience

private extension VimBuffer {
    func withPendingCleared() -> VimBuffer {
        var b = self; b.pending = ""; return b
    }
}
