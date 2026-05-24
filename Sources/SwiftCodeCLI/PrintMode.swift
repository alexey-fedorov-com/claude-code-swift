// PrintMode.swift
// SwiftCodeCLI
//
// Non-interactive -p/--print mode.
// Sends one prompt to QueryEngine, formats the result, exits.

import Foundation
import SwiftCodeCore
import SwiftCodeAPI
import SwiftCodeAgent

// MARK: - PrintModeError

public enum PrintModeError: Error, Sendable {
    case missingPrompt
    case apiKeyNotFound
    case queryFailed(underlying: Error)
}

// MARK: - PrintMode

public struct PrintMode: Sendable {

    // MARK: - Public Entry Point

    /// Run print mode: query the model and write output to `io`.
    ///
    /// - Parameters:
    ///   - prompt:       The user's prompt text.
    ///   - outputFormat: How to format the response.
    ///   - model:        Model alias or canonical ID.
    ///   - systemPrompt: Optional system prompt override.
    ///   - apiKey:       Anthropic API key (falls back to ANTHROPIC_API_KEY env var).
    ///   - io:           Output destination. Defaults to stdout / text mode.
    /// - Returns: Process exit code (0 = success, 1 = error).
    public static func run(
        prompt: String,
        outputFormat: OutputFormat = .text,
        model: String = "claude-opus-4-6",
        systemPrompt: String? = nil,
        apiKey: String? = nil,
        io: StructuredIO? = nil
    ) async -> Int32 {
        let resolvedIO = io ?? StructuredIO(format: outputFormat)

        guard !prompt.isEmpty else {
            try? resolvedIO.writeError(PrintModeError.missingPrompt)
            return 1
        }

        do {
            // Explicit --api-key wins; otherwise fall through env → keychain via
            // the composite provider so users who logged in interactively can
            // use -p mode without re-exporting their key.
            let client: AnthropicClient
            if let key = apiKey, !key.isEmpty {
                client = AnthropicClient(apiKey: key)
            } else {
                client = AnthropicClient(authProvider: CompositeAuthProvider.makeDefault())
            }
            let engine = QueryEngine(client: client, model: model)

            if outputFormat == .streamJSON {
                return await runStreaming(
                    prompt: prompt,
                    engine: engine,
                    systemPrompt: systemPrompt,
                    io: resolvedIO
                )
            } else {
                return await runBlocking(
                    prompt: prompt,
                    engine: engine,
                    systemPrompt: systemPrompt,
                    io: resolvedIO
                )
            }
        }
    }

    // MARK: - Private: Blocking (text / json)

    private static func runBlocking(
        prompt: String,
        engine: QueryEngine,
        systemPrompt: String?,
        io: StructuredIO
    ) async -> Int32 {
        do {
            let message = try await engine.run(
                userMessage: prompt,
                systemPrompt: systemPrompt
            )
            try io.writeMessage(message)
            return 0
        } catch {
            try? io.writeError(error)
            return 1
        }
    }

    // MARK: - Private: Streaming (stream-json)

    private static func runStreaming(
        prompt: String,
        engine: QueryEngine,
        systemPrompt: String?,
        io: StructuredIO
    ) async -> Int32 {
        // For stream-json we emit one event per SSE chunk.
        // QueryEngine doesn't expose streaming directly, but QueryLoop does.
        // For simplicity in print mode, we use the non-streaming path and
        // emit a single synthetic stream of events from the completed response.
        // A full streaming implementation can be added in a later task.
        do {
            let message = try await engine.run(
                userMessage: prompt,
                systemPrompt: systemPrompt
            )

            // Emit synthetic stream events: message_start → content_block deltas → message_stop
            let sessionId = UUID().uuidString
            try io.writeSessionStart(sessionId: sessionId)

            // Emit content as text delta events
            for block in message.content {
                if case .text(let text) = block {
                    try io.writeTextDelta(text)
                }
            }

            // Emit the final message envelope
            try io.writeMessage(message)

            return 0
        } catch {
            try? io.writeError(error)
            return 1
        }
    }
}
