import Foundation

/// State machine for the in-REPL `/login` flow.
///
/// The REPL drives this state via background tasks (validate key, exchange OAuth
/// code, etc.) while the reducer routes keypresses to the appropriate stage.
public enum LoginFlowState: Sendable, Equatable {
    /// Top-level menu: 1 = API key, 2 = OAuth.
    case menu

    /// User is typing/pasting an API key. The buffer is masked when rendered.
    case apiKeyEntry(buffer: String)

    /// We're calling /v1/models to verify the key — shows a spinner.
    case validatingApiKey

    /// OAuth started: browser opening + server listening for callback.
    /// `authorizeURL` is shown for manual copy-paste fallback.
    case oauthWaiting(authorizeURL: String)

    /// OAuth callback received, exchanging code for token.
    case oauthExchanging

    /// Terminal states.
    case success(message: String)
    case error(message: String)
}
