#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

import Foundation

/// Handles writing to stdout with optional buffering, and terminal screen clearing.
public final class TerminalOutput {

    public enum ClearMode {
        case screen      // clear entire screen
        case toEndOfLine // clear from cursor to end of line
        case scrollback  // clear scrollback buffer
    }

    private var buffer: String = ""
    private let useBuffering: Bool

    public init(useBuffering: Bool = true) {
        self.useBuffering = useBuffering
    }

    // MARK: - Write API

    /// Write a string to stdout (buffered or immediate).
    public func write(_ string: String) {
        if useBuffering {
            buffer += string
        } else {
            flush(string)
        }
    }

    /// Flush the internal buffer to stdout.
    public func flush() {
        guard useBuffering && !buffer.isEmpty else { return }
        flush(buffer)
        buffer = ""
    }

    // MARK: - Cursor / Screen control

    /// Move cursor to absolute position (1-indexed).
    public func moveCursor(row: Int, col: Int) {
        write("\u{1B}[\(row);\(col)H")
    }

    /// Move cursor to top-left (home).
    public func cursorHome() {
        write("\u{1B}[H")
    }

    /// Hide the terminal cursor.
    public func hideCursor() {
        write("\u{1B}[?25l")
    }

    /// Show the terminal cursor.
    public func showCursor() {
        write("\u{1B}[?25h")
    }

    /// Clear the screen.
    public func clear(_ mode: ClearMode = .screen) {
        switch mode {
        case .screen:
            write("\u{1B}[2J")
        case .toEndOfLine:
            write("\u{1B}[K")
        case .scrollback:
            write("\u{1B}[3J")
        }
    }

    /// Clear screen and move cursor home (common pattern for re-rendering).
    public func clearAndHome() {
        clear(.screen)
        cursorHome()
    }

    /// Write a complete frame: clear + content + flush.
    public func renderFrame(_ content: String) {
        clearAndHome()
        write(content)
        write("\n")
        flush()
    }

    // MARK: - Private

    private func flush(_ string: String) {
        var data = string
        data.withUTF8 { ptr in
            _ = Darwin.write(STDOUT_FILENO, ptr.baseAddress, ptr.count)
        }
    }
}
