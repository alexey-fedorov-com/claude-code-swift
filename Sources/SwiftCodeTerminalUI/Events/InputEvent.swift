/// All input events the terminal can produce.
public enum InputEvent: Equatable {
    // Printable characters
    case character(Character)

    // Control characters (Ctrl+A = 1, Ctrl+B = 2, ..., Ctrl+Z = 26)
    case controlChar(Character) // the letter, e.g. 'c' for Ctrl+C

    // Navigation
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight

    // Editing keys
    case enter
    case tab
    case backspace
    case delete
    case escape

    // Function keys F1–F12
    case functionKey(Int)

    // Modifier + arrow
    case shiftArrowUp
    case shiftArrowDown
    case shiftArrowLeft
    case shiftArrowRight

    // Bracketed paste
    case paste(String)

    // Focus events
    case focus
    case blur

    // Window resize
    case resize(rows: Int, cols: Int)

    // Mouse (basic position + button)
    case mousePress(button: Int, row: Int, col: Int)
    case mouseRelease(button: Int, row: Int, col: Int)

    // Unknown/unparsed sequence
    case unknown([UInt8])
}
