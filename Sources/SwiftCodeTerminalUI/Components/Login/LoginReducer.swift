/// Routes key events while a `LoginFlowState` is active.
///
/// Returns `true` when the user pressed a key that the REPL must act on
/// outside of pure UI state (e.g. menu choice picked, API key submitted,
/// or login dismissed). The REPL polls `state.loginFlow` to decide what
/// background work to kick off.
public enum LoginReducer {

    /// The high-level event the REPL should react to after this reducer ran.
    /// `nil` means "pure state change, no action needed."
    public enum Outcome: Sendable, Equatable {
        case chooseApiKey
        case chooseOAuth
        case submitApiKey(String)
        case cancel
        case dismiss
    }

    /// Mutates `state.loginFlow` and reports the high-level outcome.
    public static func reduce(event: InputEvent, to state: inout ChatScreenState) -> Outcome? {
        guard let flow = state.loginFlow else { return nil }

        switch flow {
        case .menu:
            switch event {
            case .character("1"):
                state.loginFlow = .apiKeyEntry(buffer: "")
                return .chooseApiKey
            case .character("2"):
                return .chooseOAuth
            case .escape, .controlChar("c"):
                state.loginFlow = nil
                return .cancel
            default:
                return nil
            }

        case .apiKeyEntry(let buffer):
            switch event {
            case .escape:
                state.loginFlow = nil
                return .cancel
            case .enter:
                let trimmed = buffer.trimmingWhitespace()
                if trimmed.isEmpty { return nil }
                return .submitApiKey(trimmed)
            case .character(let c) where c == "\r" || c == "\n":
                let trimmed = buffer.trimmingWhitespace()
                if trimmed.isEmpty { return nil }
                return .submitApiKey(trimmed)
            case .backspace:
                if !buffer.isEmpty {
                    state.loginFlow = .apiKeyEntry(buffer: String(buffer.dropLast()))
                }
                return nil
            case .character(let c):
                if c.isASCII && !c.isNewline {
                    state.loginFlow = .apiKeyEntry(buffer: buffer + String(c))
                }
                return nil
            case .paste(let s):
                state.loginFlow = .apiKeyEntry(buffer: buffer + s)
                return nil
            default:
                return nil
            }

        case .validatingApiKey, .oauthExchanging:
            // Block input during work — only allow Ctrl+C to bail.
            if case .controlChar("c") = event {
                state.loginFlow = nil
                return .cancel
            }
            return nil

        case .oauthWaiting:
            // Allow cancel while waiting for the browser callback.
            switch event {
            case .escape, .controlChar("c"):
                state.loginFlow = nil
                return .cancel
            default:
                return nil
            }

        case .success, .error:
            // Any key dismisses the terminal state.
            state.loginFlow = nil
            return .dismiss
        }
    }

    /// Convenience used by `REPLReducer.apply` — performs the state mutation
    /// and discards the outcome (the REPL loop separately polls outcomes
    /// via `reduce(...)` when it needs them).
    @discardableResult
    public static func apply(event: InputEvent, to state: inout ChatScreenState) -> Bool {
        _ = reduce(event: event, to: &state)
        return false
    }
}

private extension String {
    func trimmingWhitespace() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
