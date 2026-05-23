// InteractiveREPL.swift
// SwiftCodeCLI
//
// Interactive REPL loop.
// Reads lines from stdin, dispatches slash commands or sends queries to the model.
// Mirrors the main REPL in .reference/src/screens/REPL.tsx (headless / line-based port).

import Foundation
import SwiftCodeCore
import SwiftCodeAPI
import SwiftCodeAgent
import SwiftCodeCommands

// MARK: - REPLError

public enum REPLError: Error, Sendable {
    case exitRequested(Int32)
    case stdinClosed
}

// MARK: - InteractiveREPL

/// Line-based interactive REPL.
///
/// Reads prompts from stdin, dispatches slash commands via `CommandRegistry`,
/// sends non-slash input to `QueryEngine`, and prints responses to stdout.
public actor InteractiveREPL {

    // MARK: - State

    private let client: any AnthropicAPI
    private let registry: CommandRegistry
    private let model: String
    private let systemPrompt: String?
    private var conversationHistory: [Message] = []
    private let io: StructuredIO

    // MARK: - Init

    public init(
        client: any AnthropicAPI,
        registry: CommandRegistry? = nil,
        model: String = "claude-opus-4-6",
        systemPrompt: String? = nil,
        io: StructuredIO = StructuredIO(format: .text)
    ) {
        self.client = client
        self.registry = registry ?? CommandRegistry.defaultRegistry()
        self.model = model
        self.systemPrompt = systemPrompt
        self.io = io
    }

    // MARK: - Run

    /// Start the interactive REPL. Returns when the user exits.
    public func run() async -> Int32 {
        printBanner()

        while true {
            // Print prompt indicator
            printPrompt()

            // Read line from stdin
            guard let line = readLine(strippingNewline: true) else {
                // EOF / Ctrl+D — exit gracefully
                printLine("\nGoodbye.")
                return 0
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty input
            if trimmed.isEmpty { continue }

            // Dispatch slash command or query
            if trimmed.hasPrefix("/") {
                let exitCode = await handleSlashCommand(trimmed)
                if let code = exitCode {
                    return code
                }
            } else {
                await handleQuery(trimmed)
            }
        }
    }

    // MARK: - Slash Command Dispatch

    /// Parse and execute a slash command. Returns exit code if REPL should stop, nil to continue.
    private func handleSlashCommand(_ input: String) async -> Int32? {
        // Strip leading "/"
        let withoutSlash = String(input.dropFirst())

        // Split on first space: command name + rest
        let parts = withoutSlash.split(separator: " ", maxSplits: 1)
        let commandName = parts.isEmpty ? "" : String(parts[0]).lowercased()
        let commandInput = parts.count > 1 ? String(parts[1]) : ""

        let context = makeContext()

        guard let command = await registry.lookup(name: commandName) else {
            printLine("Unknown command: /\(commandName). Type /help for a list of commands.")
            return nil
        }

        do {
            let result = try await command.execute(input: commandInput, context: context)
            return handle(result: result)
        } catch {
            printLine("Command error: \(error)")
            return nil
        }
    }

    /// Handle a `SlashCommandResult`. Returns exit code if REPL should stop, nil to continue.
    private func handle(result: SlashCommandResult) -> Int32? {
        switch result {
        case .message(let text):
            printLine(text)
            return nil

        case .exit(let code):
            printLine("Exiting...")
            return code

        case .clearContext:
            conversationHistory = []
            printLine("Conversation cleared.")
            return nil

        case .setModel(let newModel):
            // Model change is noted — in a full implementation we'd update state
            printLine("Model set to: \(newModel)")
            return nil

        case .promptInjection(let text):
            // Treat injected text as a user query
            Task {
                await handleQuery(text)
            }
            return nil

        case .noop:
            return nil
        }
    }

    // MARK: - Query Dispatch

    private func handleQuery(_ userInput: String) async {
        // Build message history
        let userMsg = UserMessage(uuid: UUID().uuidString, content: .text(userInput), isMeta: false)
        conversationHistory.append(.user(userMsg))

        let engine = QueryEngine(client: client, model: model)

        do {
            let assistantMessage: AssistantMessage
            if conversationHistory.count == 1 {
                // First turn: simple single-message query
                assistantMessage = try await engine.run(
                    userMessage: userInput,
                    systemPrompt: systemPrompt
                )
            } else {
                // Multi-turn: pass full history
                assistantMessage = try await engine.run(
                    messages: conversationHistory,
                    systemPrompt: systemPrompt
                )
            }

            // Append assistant message to history
            conversationHistory.append(.assistant(assistantMessage))

            // Print response
            let text = assistantMessage.content.compactMap { block -> String? in
                if case .text(let t) = block { return t }
                return nil
            }.joined()

            printLine(text)

        } catch {
            printLine("Error: \(error)")
            // Remove the user message from history on error so it's not retried
            conversationHistory.removeLast()
        }
    }

    // MARK: - Context

    private func makeContext() -> SlashCommandContext {
        SlashCommandContext(
            sessionId: UUID().uuidString,
            workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            currentModel: model,
            isAntUser: false,
            isDemoMode: false
        )
    }

    // MARK: - Output Helpers

    private func printBanner() {
        printLine("╔══════════════════════════════╗")
        printLine("║   SwiftCode (Claude Code)    ║")
        printLine("║   Type /help for commands    ║")
        printLine("║   Ctrl+D to exit             ║")
        printLine("╚══════════════════════════════╝")
        printLine("")
    }

    private func printPrompt() {
        // Print without newline — user types on same line
        let data = Data("> ".utf8)
        FileHandle.standardOutput.write(data)
    }

    private func printLine(_ text: String) {
        let data = Data((text + "\n").utf8)
        FileHandle.standardOutput.write(data)
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
