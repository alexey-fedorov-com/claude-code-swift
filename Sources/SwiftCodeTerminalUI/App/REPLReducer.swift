import SwiftCodeNative

// MARK: - REPLReducer

public enum REPLReducer {
    /// Applies an input event to chat state. Returns true if the event was a "submit" gesture
    /// (Enter on a non-empty cursor) that the caller should dispatch to the model.
    @discardableResult
    public static func apply(event: InputEvent, to state: inout ChatScreenState) -> Bool {
        // Login flow takes over input entirely while active. The detailed
        // outcome (menu choice, key submission, etc.) is exposed via
        // `applyAndCollectLoginOutcome`; callers that just need state changes
        // can keep using `apply`.
        if state.loginFlow != nil {
            _ = LoginReducer.reduce(event: event, to: &state)
            return false
        }

        // When suggestions are active, route navigation/confirm/dismiss keys first.
        if state.suggestionTrigger != nil {
            switch event {
            case .arrowUp:
                state.suggestionSelectedIndex = max(0, state.suggestionSelectedIndex - 1)
                return false
            case .arrowDown:
                state.suggestionSelectedIndex = min(
                    state.suggestions.count - 1,
                    state.suggestionSelectedIndex + 1
                )
                return false
            case .escape:
                state.suggestions = []
                state.suggestionTrigger = nil
                state.suggestionSelectedIndex = 0
                return false
            case .tab:
                applySelectedSuggestion(state: &state)
                return false
            case .character(let c) where c == "\t":
                applySelectedSuggestion(state: &state)
                return false
            case .enter:
                // Enter inserts the highlighted suggestion (not a submit)
                applySelectedSuggestion(state: &state)
                return false
            case .character(let c) where c == "\n" || c == "\r":
                applySelectedSuggestion(state: &state)
                return false
            default:
                break
            }
        }

        // Normal input handling
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

        recomputeSuggestions(state: &state)
        return false
    }

    /// Same as `apply` but also surfaces any login-flow outcome so the REPL
    /// loop can kick off background work (validating an API key, starting
    /// OAuth, etc.). Use this from REPLs that drive the login flow.
    public static func applyAndCollectLoginOutcome(
        event: InputEvent,
        to state: inout ChatScreenState
    ) -> (didSubmit: Bool, login: LoginReducer.Outcome?) {
        if state.loginFlow != nil {
            let outcome = LoginReducer.reduce(event: event, to: &state)
            return (false, outcome)
        }
        let submitted = apply(event: event, to: &state)
        return (submitted, nil)
    }

    // MARK: - Internal helpers (internal so tests can call them if needed)

    static func recomputeSuggestions(state: inout ChatScreenState) {
        if let slash = SlashCommandSuggestions.detectTrigger(
            text: state.cursor.text,
            cursorOffset: state.cursor.offset
        ) {
            state.suggestionTrigger = .slash(slash)
            state.suggestions = SlashCommandSuggestions
                .filter(prefix: slash.prefix, commands: state.availableCommands)
                .prefix(20)
                .map { .command($0) }
        } else if let at = AtMentionSuggestions.detectTrigger(
            text: state.cursor.text,
            cursorOffset: state.cursor.offset
        ) {
            let split = AtMentionSuggestions.splitDirectoryAndPrefix(at.partialPath)
            let scanDir = split.directory.isEmpty
                ? state.workingDirectory
                : "\(state.workingDirectory)/\(split.directory)"
            let entries = (try? PathCompletion.complete(prefix: split.prefix, in: scanDir)) ?? []
            if !entries.isEmpty {
                state.suggestionTrigger = .atMention(at)
                state.suggestions = entries.prefix(20).map {
                    .path(PathSuggestion(
                        display: split.directory.isEmpty ? $0.name : "\(split.directory)/\($0.name)",
                        isDirectory: $0.kind == .directory
                    ))
                }
            } else {
                state.suggestions = []
                state.suggestionTrigger = nil
            }
        } else {
            state.suggestions = []
            state.suggestionTrigger = nil
        }
        if state.suggestionSelectedIndex >= state.suggestions.count {
            state.suggestionSelectedIndex = 0
        }
    }

    static func applySelectedSuggestion(state: inout ChatScreenState) {
        guard state.suggestionSelectedIndex < state.suggestions.count else { return }
        let pick = state.suggestions[state.suggestionSelectedIndex]
        switch (state.suggestionTrigger, pick) {
        case (.slash(let trig)?, .command(let cmd)):
            state.cursor = SlashCommandSuggestions.apply(
                cursor: state.cursor,
                trigger: trig,
                selection: cmd
            )
        case (.atMention(let trig)?, .path(let p)):
            state.cursor = AtMentionSuggestions.apply(
                cursor: state.cursor,
                trigger: trig,
                selection: p
            )
        default:
            break
        }
        state.suggestions = []
        state.suggestionTrigger = nil
        state.suggestionSelectedIndex = 0
    }
}
