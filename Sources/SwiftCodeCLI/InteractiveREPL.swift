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
                }
                let result = SubmitResult()
                await app.withState { state in
                    let submitted = REPLReducer.apply(event: event, to: &state)
                    result.didSubmit = submitted
                    if submitted {
                        result.submittedText = state.cursor.text
                        state.messages.append(.user(result.submittedText))
                        state.cursor = TextCursor()
                        state.isLoading = true
                    }
                }
                await app.renderFrameIfNeeded()
                if result.didSubmit {
                    let submittedText = result.submittedText
                    // Check for exit commands
                    if submittedText == "/exit" || submittedText == "/quit" {
                        continuation.yield(0)
                        return
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
