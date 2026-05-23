public enum ANSIEscapes {
    public static let esc = "\u{1B}"
    public static let csi = "\u{1B}["
    public static func cursorTo(row: Int, col: Int) -> String { "\(csi)\(row);\(col)H" }
    public static let enterAltScreen = "\(csi)?1049h"
    public static let exitAltScreen = "\(csi)?1049l"
    public static let hideCursor = "\(csi)?25l"
    public static let showCursor = "\(csi)?25h"
    public static let clearScreen = "\(csi)2J"
    public static let clearLine = "\(csi)2K"
    public static let enableBracketedPaste = "\(csi)?2004h"
    public static let disableBracketedPaste = "\(csi)?2004l"
    public static let enableFocusEvents = "\(csi)?1004h"
    public static let disableFocusEvents = "\(csi)?1004l"
    public static let sgrReset = "\(csi)0m"
    public static let saveCursor = "\(csi)s"
    public static let restoreCursor = "\(csi)u"
}
