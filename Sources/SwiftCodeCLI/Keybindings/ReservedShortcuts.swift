/// ReservedShortcuts — key combinations that cannot be rebound.
///
/// These are either OS-level (Ctrl+C SIGINT, Ctrl+Z SIGTSTP) or
/// hard-wired in the terminal input layer and must not be reassigned.

// MARK: - ReservedShortcuts

public enum ReservedShortcuts {
    /// Returns the full set of reserved key combo strings.
    ///
    /// Key combo notation matches `Keybinding.key` format (lowercase modifiers,
    /// `+` separator, e.g. `"ctrl+c"`).
    public static func all() -> Set<String> {
        [
            // Unix process control
            "ctrl+c",   // SIGINT
            "ctrl+d",   // EOF / exit
            "ctrl+z",   // SIGTSTP
            "ctrl+\\",  // SIGQUIT

            // Terminal input control
            "ctrl+q",   // XON
            "ctrl+s",   // XOFF (flow control — may be caught by terminal)

            // Hard-wired readline / terminal actions that bypass the app
            "ctrl+r",   // reverse-i-search (bash/zsh readline)

            // macOS system shortcuts (cmd-based)
            "cmd+space",        // Spotlight
            "cmd+tab",          // App switcher
            "cmd+`",            // Window switcher
            "cmd+q",            // Quit application
            "cmd+m",            // Minimize window
            "cmd+h",            // Hide window
        ]
    }

    /// Returns true if `key` is in the reserved set (case-insensitive).
    public static func isReserved(_ key: String) -> Bool {
        all().contains(key.lowercased())
    }
}
