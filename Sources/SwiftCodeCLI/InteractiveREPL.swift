// InteractiveREPL.swift
// SwiftCodeCLI
//
// TUI interactive REPL — composes ChatScreen + App<ChatScreenState> + EventLoop.
// Replaces the old readLine-based loop with a full terminal UI.

import Foundation
import SwiftCodeCore
import SwiftCodeAPI
import SwiftCodeAgent
import SwiftCodeCommands
import SwiftCodeTerminalUI

// MARK: - REPLError

public enum REPLError: Error, Sendable {
    case exitRequested(Int32)
    case stdinClosed
}

// MARK: - InteractiveREPL

public actor InteractiveREPL {

    // MARK: - State

    private let client: any AnthropicAPI
    private let registry: CommandRegistry
    private let model: String
    private let systemPrompt: String?
    private var conversationHistory: [Message] = []

    // MARK: - Init

    public init(
        client: any AnthropicAPI,
        registry: CommandRegistry? = nil,
        model: String = "claude-opus-4-6",
        systemPrompt: String? = nil
    ) {
        self.client = client
        self.registry = registry ?? CommandRegistry.defaultRegistry()
        self.model = model
        self.systemPrompt = systemPrompt
    }

    // MARK: - Run

    /// Start the interactive TUI REPL. Returns when the user exits.
    public func run() async -> Int32 {
        AppLifecycle.installSignalHandlers()
        AppLifecycle.enter()
        defer { AppLifecycle.leave() }

        let size = AppLifecycle.terminalSize()
        let availableCommandsList = await registry.availableCommands(antUser: false, demoMode: false)
        let commandSuggestions = availableCommandsList.map { cmd in
            CommandSuggestion(name: cmd.name, description: cmd.description)
        }
        let initialState = ChatScreenState(
            version: SwiftCodeVersion.value,
            cwd: FileManager.default.currentDirectoryPath,
            width: size.width,
            availableCommands: commandSuggestions,
            workingDirectory: FileManager.default.currentDirectoryPath
        )

        let app = App<ChatScreenState>(
            initialState: initialState,
            view: { state in ChatScreen(state: state) },
            update: { event, state in _ = REPLReducer.apply(event: event, to: &state) },
            io: FileHandleIO(),
            width: size.width,
            height: size.height
        )
        await app.renderInitialFrame()

        // Channel for exit-code signaling (Ctrl-C or /exit)
        let (stream, continuation) = AsyncStream<Int32>.makeStream()

        // Spinner ticker — fires every 80ms while running
        let spinnerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 80_000_000)
                await app.tickSpinner()
                // Sync spinner frame into state so ChatScreen renders it
                let frame = await app.currentSpinnerFrame()
                await app.withState { state in
                    state.spinnerFrame = frame
                }
                await app.renderFrameIfNeeded()
            }
        }

        let modelCopy = model
        let systemPromptCopy = systemPrompt
        let clientCopy = client
        let registryCopy = registry

        // Event loop: reads raw key events on a background thread
        let loop = EventLoop(onEvent: { event in
            Task { [continuation] in
                // Handle Ctrl-C immediately
                if case .controlChar(let c) = event, c == "c" {
                    continuation.yield(0)
                    return
                }
                // Snapshot whether this is a submit before mutating state.
                // We use a nonisolated container to pass the result out of the @Sendable closure.
                final class SubmitResult: @unchecked Sendable {
                    var didSubmit = false
                    var submittedText = ""
                    var loginOutcome: LoginReducer.Outcome?
                }
                let result = SubmitResult()
                await app.withState { state in
                    let r = REPLReducer.applyAndCollectLoginOutcome(event: event, to: &state)
                    result.didSubmit = r.didSubmit
                    result.loginOutcome = r.login
                    if r.didSubmit {
                        result.submittedText = state.cursor.text
                        state.messages.append(.user(result.submittedText))
                        state.cursor = TextCursor()
                        state.isLoading = true
                    }
                }
                await app.renderFrameIfNeeded()

                // Handle login flow side-effects before anything else.
                if let outcome = result.loginOutcome {
                    Task {
                        await Self.handleLoginOutcome(
                            outcome,
                            app: app,
                            continuation: continuation
                        )
                    }
                    return
                }

                if result.didSubmit {
                    let submittedText = result.submittedText
                    // Slash command routing
                    if submittedText.hasPrefix("/") {
                        if let parsed = parseSlashCommand(submittedText) {
                            Task { [continuation] in
                                await Self.dispatchSlashCommand(
                                    name: parsed.name,
                                    args: parsed.args,
                                    app: app,
                                    registry: registryCopy,
                                    continuation: continuation
                                )
                            }
                            return
                        }
                    }
                    // Dispatch to model in background
                    Task {
                        await Self.dispatchQuery(
                            text: submittedText,
                            app: app,
                            client: clientCopy,
                            model: modelCopy,
                            systemPrompt: systemPromptCopy
                        )
                    }
                }
            }
        })
        loop.start()

        var exitCode: Int32 = 0
        for await code in stream {
            exitCode = code
            break
        }
        spinnerTask.cancel()
        loop.stop()
        return exitCode
    }

    // MARK: - Query Dispatch

    private static func dispatchQuery(
        text: String,
        app: App<ChatScreenState>,
        client: any AnthropicAPI,
        model: String,
        systemPrompt: String?
    ) async {
        let engine = QueryEngine(client: client, model: model)
        do {
            let response = try await engine.run(userMessage: text, systemPrompt: systemPrompt)
            let assistantText = response.content.compactMap { block -> String? in
                if case .text(let t) = block { return t }
                return nil
            }.joined()
            await app.withState { state in
                state.messages.append(.assistant(assistantText))
                state.isLoading = false
            }
        } catch {
            await app.withState { state in
                state.messages.append(.system("Error: \(error)"))
                state.isLoading = false
            }
        }
        await app.renderFrameIfNeeded()
    }

    // MARK: - Slash Command Dispatch

    private static func dispatchSlashCommand(
        name: String,
        args: String,
        app: App<ChatScreenState>,
        registry: CommandRegistry,
        continuation: AsyncStream<Int32>.Continuation
    ) async {
        guard let command = await registry.lookup(name: name) else {
            await app.withState { state in
                state.messages.append(.system("Unknown command: /\(name) — try /help"))
                state.isLoading = false
            }
            await app.renderFrameIfNeeded()
            return
        }

        let context = SlashCommandContext(
            workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )

        let result: SlashCommandResult
        do {
            result = try await command.execute(input: args, context: context)
        } catch {
            await app.withState { state in
                state.messages.append(.system("Command /\(name) failed: \(error)"))
                state.isLoading = false
            }
            await app.renderFrameIfNeeded()
            return
        }

        switch result {
        case .message(let text):
            await app.withState { state in
                state.messages.append(.system(text))
                state.isLoading = false
            }
        case .noop:
            await app.withState { state in
                state.isLoading = false
            }
        case .exit(let code):
            continuation.yield(code)
            return
        case .clearContext:
            await app.withState { state in
                state.messages = []
                state.isLoading = false
            }
        case .setModel(let m):
            await app.withState { state in
                state.messages.append(.system("Switched model → \(m)"))
                state.isLoading = false
            }
        case .promptInjection(let text):
            await app.withState { state in
                state.cursor = TextCursor(text: text, offset: text.count)
                state.isLoading = false
            }
        case .showLoginFlow:
            await app.withState { state in
                state.loginFlow = .menu
                state.isLoading = false
            }
        case .logoutCompleted(let message):
            await app.withState { state in
                state.messages.append(.system(message))
                state.isLoading = false
            }
        }
        await app.renderFrameIfNeeded()
    }

    // MARK: - Login Flow Side Effects

    private static func handleLoginOutcome(
        _ outcome: LoginReducer.Outcome,
        app: App<ChatScreenState>,
        continuation: AsyncStream<Int32>.Continuation
    ) async {
        switch outcome {
        case .chooseApiKey:
            // Pure state transition; LoginReducer already set apiKeyEntry.
            await app.renderFrameIfNeeded()

        case .submitApiKey(let key):
            await app.withState { state in
                state.loginFlow = .validatingApiKey
            }
            await app.renderFrameIfNeeded()
            await Self.runApiKeyValidation(key: key, app: app)

        case .chooseOAuth:
            await Self.runOAuthFlow(app: app)

        case .cancel:
            await app.withState { state in
                state.messages.append(.system("Login cancelled."))
            }
            await app.renderFrameIfNeeded()

        case .dismiss:
            await app.renderFrameIfNeeded()
        }
    }

    private static func runApiKeyValidation(
        key: String,
        app: App<ChatScreenState>
    ) async {
        let validator = ApiKeyValidator()
        let result = await validator.validate(apiKey: key)
        await validator.shutdown()

        switch result {
        case .valid:
            do {
                try CredentialStore().saveApiKey(key)
                await app.withState { state in
                    state.loginFlow = .success(message: "API key saved to Keychain. You're logged in.")
                }
            } catch {
                await app.withState { state in
                    state.loginFlow = .error(message: "Validated, but failed to save to Keychain: \(error)")
                }
            }
        case .invalid(let reason):
            await app.withState { state in
                state.loginFlow = .error(message: reason)
            }
        case .transientError(let msg):
            await app.withState { state in
                state.loginFlow = .error(message: "Could not reach Anthropic: \(msg)")
            }
        }
        await app.renderFrameIfNeeded()
    }

    private static func runOAuthFlow(app: App<ChatScreenState>) async {
        let server = CallbackServer()
        let port: Int
        do {
            port = try await server.start()
        } catch {
            await app.withState { state in
                state.loginFlow = .error(message: "Could not start callback listener: \(error)")
            }
            await app.renderFrameIfNeeded()
            return
        }

        let service = OAuthService()
        let request = await service.prepareAuthorization(redirectPort: port)
        let urlString = request.authorizeURL.absoluteString

        await app.withState { state in
            state.loginFlow = .oauthWaiting(authorizeURL: urlString)
        }
        await app.renderFrameIfNeeded()

        _ = BrowserLauncher.open(request.authorizeURL)

        do {
            let captured = try await server.waitForCallback(timeoutSeconds: 300)
            await server.stop()

            let code = try await service.extractCode(from: captured, expectedState: request.state)

            await app.withState { state in
                state.loginFlow = .oauthExchanging
            }
            await app.renderFrameIfNeeded()

            let token = try await service.exchange(code: code, request: request)
            try CredentialStore().saveOAuthToken(token)
            await app.withState { state in
                state.loginFlow = .success(message: "Signed in with Claude. Token saved to Keychain.")
            }
        } catch {
            await server.stop()
            await app.withState { state in
                state.loginFlow = .error(message: "OAuth failed: \(error)")
            }
        }
        await service.shutdown()
        await app.renderFrameIfNeeded()
    }
}

// MARK: - Slash Command Parsing Utilities (testable)

/// Parse a raw slash command line into (commandName, arguments).
/// The leading "/" is stripped; the command name is lowercased.
///
/// Example: "/model claude-opus-4-6" → ("model", "claude-opus-4-6")
/// Example: "/help" → ("help", "")
public func parseSlashCommand(_ input: String) -> (name: String, args: String)? {
    guard input.hasPrefix("/") else { return nil }
    let withoutSlash = String(input.dropFirst())
    guard !withoutSlash.isEmpty else { return nil }
    let parts = withoutSlash.split(separator: " ", maxSplits: 1)
    let name = String(parts[0]).lowercased()
    let args = parts.count > 1 ? String(parts[1]) : ""
    return (name, args)
}
