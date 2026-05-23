import SwiftCodeCore
import Foundation

// MARK: - VimCommand
// Mirrors: .reference/src/commands/vim/

/// Toggle vim keybinding mode in the REPL input.
///
/// In the reference, this toggles `userConfig.vim` and re-renders the input line.
/// The Swift port signals the toggle via `.promptInjection` with a special
/// sentinel so the REPL (Task 15) / Vim module (Task 18) can intercept it.
///
/// The sentinel format is: `__VIM_TOGGLE__`
/// A dedicated constant is exported so callers can match without string literals.
public struct VimCommand: SlashCommand {
    public let name = "vim"
    public let description = "Toggle between Vim and Normal editing modes"
    public let aliases: [String] = []
    public let isHidden = false
    public let supportsNonInteractive = false

    /// Sentinel injected into the prompt stream to signal a vim mode toggle.
    public static let toggleSentinel = "__VIM_TOGGLE__"

    public init() {}

    public func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
        // TODO (Task 18): Read current vim state from settings and flip it.
        // For now, signal the toggle to the REPL via promptInjection sentinel.
        return .promptInjection(VimCommand.toggleSentinel)
    }
}
