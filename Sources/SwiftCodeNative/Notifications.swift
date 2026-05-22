/// macOS user notification sender.
///
/// Mirrors the TypeScript reference at:
/// - src/services/notifier.ts (sendAuto / sendToChannel for Apple_Terminal / iTerm2 paths)
///
/// The reference primarily routes through terminal escape sequences (iTerm2,
/// kitty, ghostty) or `osascript` for Apple Terminal. This Swift layer provides
/// the `osascript` bridge as the universal macOS fallback.
///
/// Terminal-escape-sequence–based notifications (iTerm2 OSC, kitty, ghostty)
/// are emitted elsewhere (TerminalUI layer). This file handles only the
/// subprocess / OS notification path.

import Foundation

// MARK: - NotificationSender

public enum NotificationSender {

    /// Sends a macOS user notification via `osascript`.
    ///
    /// This corresponds to the `display notification` AppleScript command and
    /// works in Apple Terminal, iTerm2, and most macOS terminal emulators.
    ///
    /// - Parameters:
    ///   - title: Notification title (defaults to "Claude Code").
    ///   - body: Notification body text.
    ///   - sound: When `true`, plays the default notification sound.
    public static func send(
        title: String = "Claude Code",
        body: String,
        sound: Bool = true
    ) async {
        // Escape double-quotes in title and body for AppleScript string literals
        let safeTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let safeBody = body.replacingOccurrences(of: "\"", with: "\\\"")

        var script = "display notification \"\(safeBody)\" with title \"\(safeTitle)\""
        if sound {
            script += " sound name \"default\""
        }

        let runner = ProcessRunner()
        _ = try? await runner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", script]
        )
    }

    /// Sends a notification using `terminal-notifier` if it is installed,
    /// falling back to `osascript`.
    ///
    /// `terminal-notifier` supports action buttons and persistent notifications
    /// but is not bundled with macOS, so we gracefully fall back.
    public static func sendWithFallback(
        title: String = "Claude Code",
        body: String,
        sound: Bool = true
    ) async {
        // Check for terminal-notifier on PATH
        let whichRunner = ProcessRunner()
        let which = try? await whichRunner.run(
            executable: "/usr/bin/which",
            arguments: ["terminal-notifier"]
        )

        if let which, which.exitCode == 0,
           !which.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let notifierPath = which.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            var args = ["-title", title, "-message", body]
            if sound { args += ["-sound", "default"] }

            let runner = ProcessRunner()
            _ = try? await runner.run(executable: notifierPath, arguments: args)
        } else {
            await send(title: title, body: body, sound: sound)
        }
    }
}
