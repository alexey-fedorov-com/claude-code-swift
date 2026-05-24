import Foundation

// MARK: - ChatMessage

public enum ChatMessage: Sendable, Equatable {
    case user(String)
    case assistant(String)
    case system(String)
}

// MARK: - SuggestionTriggerKind

public enum SuggestionTriggerKind: Sendable, Equatable {
    case slash(SlashTrigger)
    case atMention(AtMentionTrigger)
}

// MARK: - ChatScreenState

public struct ChatScreenState: Sendable, Equatable {
    public var version: String
    public var messages: [ChatMessage]
    public var cursor: TextCursor
    public var isLoading: Bool
    public var spinnerFrame: Int
    public var modeLabel: String?
    public var cwd: String?
    public var width: Int      // current terminal width (for prompt input sizing)

    // Suggestion / autocomplete state
    public var suggestions: [SuggestionItem] = []
    public var suggestionSelectedIndex: Int = 0
    public var suggestionTrigger: SuggestionTriggerKind? = nil
    public var availableCommands: [CommandSuggestion] = []
    public var workingDirectory: String = FileManager.default.currentDirectoryPath

    /// When non-nil, the chat screen is replaced by the login flow.
    public var loginFlow: LoginFlowState? = nil

    public init(version: String,
                messages: [ChatMessage] = [],
                cursor: TextCursor = TextCursor(),
                isLoading: Bool = false,
                spinnerFrame: Int = 0,
                modeLabel: String? = nil,
                cwd: String? = nil,
                width: Int = 80,
                availableCommands: [CommandSuggestion] = [],
                workingDirectory: String = FileManager.default.currentDirectoryPath) {
        self.version = version
        self.messages = messages
        self.cursor = cursor
        self.isLoading = isLoading
        self.spinnerFrame = spinnerFrame
        self.modeLabel = modeLabel
        self.cwd = cwd
        self.width = width
        self.availableCommands = availableCommands
        self.workingDirectory = workingDirectory
    }
}

// MARK: - ChatScreen

public struct ChatScreen: View {
    public let state: ChatScreenState

    public init(state: ChatScreenState) { self.state = state }

    public func buildLayoutNode(theme: Theme, styles: CellStyleTable) -> LayoutNode {
        var rows: [any View] = []

        // Login flow takes over the screen entirely while active.
        if let flow = state.loginFlow {
            rows.append(SpacerView())
            rows.append(LoginScreen(
                flow: flow,
                spinnerFrame: state.spinnerFrame,
                width: state.width
            ))
            rows.append(SpacerView())
            return BoxView(width: .auto, height: .auto,
                           flexDirection: .column, children: rows)
                .buildLayoutNode(theme: theme, styles: styles)
        }

        if state.messages.isEmpty {
            rows.append(WelcomeCard(
                version: state.version,
                username: nil,
                model: nil,
                cwd: state.cwd,
                width: state.width
            ))
        } else {
            let msgs: [any View] = state.messages.map { msg in
                switch msg {
                case .user(let t):       return UserMessageView(text: t) as any View
                case .assistant(let t):  return AssistantMessageView(text: t) as any View
                case .system(let t):     return SystemMessageView(text: t) as any View
                }
            }
            rows.append(MessageList(messages: msgs))
        }

        rows.append(NewlineView())

        if state.isLoading {
            rows.append(BoxView(width: .auto, flexDirection: .row, children: [
                SpinnerView(frameIndex: state.spinnerFrame, color: theme.claude),
                TextView(" thinking…", dim: true),
            ]))
            rows.append(NewlineView())
        }

        rows.append(SpacerView())

        rows.append(PromptInput(
            cursor: state.cursor,
            placeholder: "Try \"how does this work?\"",
            width: state.width
        ))

        if !state.suggestions.isEmpty {
            rows.append(SuggestionOverlay(
                items: state.suggestions,
                selectedIndex: state.suggestionSelectedIndex,
                width: state.width
            ))
        }

        rows.append(PromptInputFooter(
            modeLabel: state.modeLabel,
            modeColor: theme.autoAccept,
            shortcuts: ["⏎ send", "? help", "ctrl+c exit"],
            cwd: state.cwd
        ))

        return BoxView(width: .auto, height: .auto,
                       flexDirection: .column, children: rows)
            .buildLayoutNode(theme: theme, styles: styles)
    }
}
