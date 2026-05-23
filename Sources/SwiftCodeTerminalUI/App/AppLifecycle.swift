#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

public enum AppLifecycle {
    nonisolated(unsafe) private static var originalTermios = termios()
    nonisolated(unsafe) private static var didEnter = false

    /// Save current termios, enter alt screen, raw mode, hide cursor, enable bracketed paste + focus.
    public static func enter() {
        guard !didEnter else { return }
        didEnter = true
        tcgetattr(STDIN_FILENO, &originalTermios)
        var raw = originalTermios
        cfmakeraw(&raw)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        let setup = ANSIEscapes.enterAltScreen + ANSIEscapes.hideCursor
            + ANSIEscapes.enableBracketedPaste + ANSIEscapes.enableFocusEvents
        FileHandle.standardOutput.write(Data(setup.utf8))
    }

    /// Reverse of `enter` — restore termios + tear down ANSI modes.
    public static func leave() {
        guard didEnter else { return }
        didEnter = false
        let teardown = ANSIEscapes.disableFocusEvents + ANSIEscapes.disableBracketedPaste
            + ANSIEscapes.showCursor + ANSIEscapes.exitAltScreen + ANSIEscapes.sgrReset
        FileHandle.standardOutput.write(Data(teardown.utf8))
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
    }

    /// Install SIGINT / SIGTERM / atexit handlers to ensure `leave` runs.
    public static func installSignalHandlers() {
        signal(SIGINT)  { _ in AppLifecycle.leave(); exit(130) }
        signal(SIGTERM) { _ in AppLifecycle.leave(); exit(143) }
        atexit { AppLifecycle.leave() }
    }

    /// Current terminal size (cols, rows). Falls back to (80, 24).
    public static func terminalSize() -> (width: Int, height: Int) {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0 {
            return (Int(ws.ws_col), Int(ws.ws_row))
        }
        return (80, 24)
    }
}
