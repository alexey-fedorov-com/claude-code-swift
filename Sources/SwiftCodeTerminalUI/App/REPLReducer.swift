// MARK: - REPLReducer

public enum REPLReducer {
    /// Applies an input event to chat state. Returns true if the event was a "submit" gesture
    /// (Enter on a non-empty cursor) that the caller should dispatch to the model.
    @discardableResult
    public static func apply(event: InputEvent, to state: inout ChatScreenState) -> Bool {
        switch event {
        case .character(let c):
            if c == "\n" || c == "\r" {
                return !state.cursor.text.isEmpty
            }
            state.cursor.insert(String(c))
        case .enter:
            return !state.cursor.text.isEmpty
        case .backspace:
            state.cursor.backspace()
        case .delete:
            state.cursor.delete()
        case .arrowLeft:
            state.cursor.moveLeft()
        case .arrowRight:
            state.cursor.moveRight()
        case .paste(let s):
            state.cursor.insert(s)
        case .resize(let w, _):
            state.width = w
        default:
            break
        }
        return false
    }
}
