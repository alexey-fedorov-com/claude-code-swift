/// Terminal capability detection.
///
/// Mirrors the TypeScript reference at:
/// - src/ink/terminal.ts  (isSynchronizedOutputSupported, isProgressReportingAvailable,
///                         supportsExtendedKeys, isXtermJs)
/// - src/ink/terminal-querier.ts
///
/// Detection is purely based on environment variables — no escape sequences
/// are written to the terminal at detection time. This is correct for CLI
/// startup (fast, no I/O side effects).

import Foundation

#if canImport(Darwin)
import Darwin
#endif

// MARK: - TerminalCapabilities

/// A snapshot of what the current terminal supports, detected at process start.
public struct TerminalCapabilities: Sendable {

    /// The terminal emits hyperlink escape sequences (OSC 8).
    public let supportsHyperlinks: Bool

    /// The terminal supports the alternate screen buffer (SMCUP/RMCUP).
    public let supportsAlternateScreen: Bool

    /// The terminal supports focus-in / focus-out reporting.
    public let supportsFocusEvents: Bool

    /// The terminal supports bracketed paste mode.
    public let supportsBracketedPaste: Bool

    /// The terminal supports `DECTCEM` (cursor visibility toggle).
    public let supportsCursorVisibility: Bool

    /// The terminal can display OS notifications (escape-sequence based).
    public let supportsNotifications: Bool

    /// The terminal supports 24-bit ("true colour") ANSI codes.
    public let supportsTrueColor: Bool

    /// DEC mode 2026 (synchronized output) is supported.
    public let supportsSynchronizedOutput: Bool

    /// `STDOUT_FILENO` is connected to a TTY (not a pipe or file).
    public let isTTY: Bool

    /// Terminal width in columns (falls back to 80).
    public let columns: Int

    /// Terminal height in rows (falls back to 24).
    public let rows: Int

    /// The `TERM_PROGRAM` env value, if set.
    public let termProgram: String?

    // MARK: Detection

    /// Detects terminal capabilities from the environment and POSIX ioctls.
    public static func detect() -> TerminalCapabilities {
        let env = ProcessInfo.processInfo.environment

        let term = env["TERM"] ?? ""
        let termProgram = env["TERM_PROGRAM"]
        let termProgramVersion = env["TERM_PROGRAM_VERSION"]
        let colorterm = env["COLORTERM"] ?? ""
        let isTTY: Bool

#if canImport(Darwin)
        isTTY = isatty(STDOUT_FILENO) == 1
#else
        isTTY = false
#endif

        // --- Columns / rows via TIOCGWINSZ ---
        let (cols, rs) = terminalSize(envFallback: env)

        // --- True colour ---
        // iTerm2, kitty, WezTerm, xterm-256color with COLORTERM=truecolor / 24bit
        let supportsTrueColor = colorterm == "truecolor"
            || colorterm == "24bit"
            || termProgram == "iTerm.app"
            || termProgram == "WezTerm"
            || termProgram == "ghostty"
            || term.contains("kitty")
            || env["KITTY_WINDOW_ID"] != nil

        // --- Synchronized output (DEC mode 2026) ---
        // Mirrors `isSynchronizedOutputSupported()` in terminal.ts
        let supportsSynchronizedOutput: Bool
        if env["TMUX"] != nil {
            // tmux doesn't implement DEC 2026
            supportsSynchronizedOutput = false
        } else if let tp = termProgram, [
            "iTerm.app", "WezTerm", "WarpTerminal", "ghostty",
            "contour", "vscode", "alacritty"
        ].contains(tp) {
            supportsSynchronizedOutput = true
        } else if term.contains("kitty") || env["KITTY_WINDOW_ID"] != nil {
            supportsSynchronizedOutput = true
        } else if term == "xterm-ghostty" {
            supportsSynchronizedOutput = true
        } else if term.hasPrefix("foot") {
            supportsSynchronizedOutput = true
        } else if term.contains("alacritty") {
            supportsSynchronizedOutput = true
        } else if env["ZED_TERM"] != nil || env["WT_SESSION"] != nil {
            supportsSynchronizedOutput = true
        } else if let vteVersionStr = env["VTE_VERSION"],
                  let vteVersion = Int(vteVersionStr), vteVersion >= 6800 {
            supportsSynchronizedOutput = true
        } else {
            supportsSynchronizedOutput = false
        }

        // --- Hyperlinks (OSC 8) ---
        // iTerm2 ≥ 3.1, kitty, WezTerm, modern xterm
        let supportsHyperlinks: Bool
        if let tp = termProgram {
            switch tp {
            case "iTerm.app":
                // iTerm2 3.1+ supports OSC 8
                supportsHyperlinks = versionAtLeast(termProgramVersion, major: 3, minor: 1)
            case "WezTerm", "ghostty", "vscode":
                supportsHyperlinks = true
            default:
                supportsHyperlinks = term.contains("kitty") || env["KITTY_WINDOW_ID"] != nil
            }
        } else {
            supportsHyperlinks = term.contains("kitty") || env["KITTY_WINDOW_ID"] != nil
        }

        // --- Alternate screen ---
        // Nearly all VT100-compatible terminals support alt screen.
        let supportsAlternateScreen = isTTY && !term.isEmpty

        // --- Focus events ---
        // Supported by xterm, iTerm2, kitty, WezTerm, most modern terminals.
        let supportsFocusEvents: Bool
        if let tp = termProgram {
            supportsFocusEvents = ["iTerm.app", "WezTerm", "ghostty", "vscode"].contains(tp)
                || term.contains("kitty")
                || term.hasPrefix("xterm")
                || env["KITTY_WINDOW_ID"] != nil
        } else {
            supportsFocusEvents = term.hasPrefix("xterm") || term.contains("kitty")
        }

        // --- Bracketed paste ---
        // Same terminal set as focus events.
        let supportsBracketedPaste = supportsFocusEvents

        // --- Cursor visibility (DECTCEM) ---
        let supportsCursorVisibility = supportsAlternateScreen

        // --- Notifications ---
        // iTerm2 proprietary notification, kitty, ghostty.
        let supportsNotifications: Bool
        if let tp = termProgram {
            supportsNotifications = ["iTerm.app", "ghostty"].contains(tp)
                || term.contains("kitty")
                || env["KITTY_WINDOW_ID"] != nil
        } else {
            supportsNotifications = term.contains("kitty") || env["KITTY_WINDOW_ID"] != nil
        }

        return TerminalCapabilities(
            supportsHyperlinks: supportsHyperlinks,
            supportsAlternateScreen: supportsAlternateScreen,
            supportsFocusEvents: supportsFocusEvents,
            supportsBracketedPaste: supportsBracketedPaste,
            supportsCursorVisibility: supportsCursorVisibility,
            supportsNotifications: supportsNotifications,
            supportsTrueColor: supportsTrueColor,
            supportsSynchronizedOutput: supportsSynchronizedOutput,
            isTTY: isTTY,
            columns: cols,
            rows: rs,
            termProgram: termProgram
        )
    }

    // MARK: Private helpers

    /// Query terminal size via `TIOCGWINSZ`, falling back to env vars then
    /// sane defaults (80×24).
    private static func terminalSize(envFallback env: [String: String]) -> (Int, Int) {
        var ws = winsize()
#if canImport(Darwin)
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0,
           ws.ws_col > 0, ws.ws_row > 0 {
            return (Int(ws.ws_col), Int(ws.ws_row))
        }
#endif
        // Fall back to COLUMNS / LINES env vars
        let cols = env["COLUMNS"].flatMap(Int.init) ?? 80
        let rows = env["LINES"].flatMap(Int.init) ?? 24
        return (cols, rows)
    }

    /// Returns `true` if the dotted version string in `versionString` is at
    /// least `major.minor`.
    private static func versionAtLeast(_ versionString: String?, major: Int, minor: Int) -> Bool {
        guard let v = versionString else { return false }
        let parts = v.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return (parts.first ?? 0) >= major }
        if parts[0] != major { return parts[0] > major }
        return parts[1] >= minor
    }
}

// MARK: - Convenience

public extension TerminalCapabilities {
    /// Shared instance detected once at process startup.
    static let current: TerminalCapabilities = detect()
}
