// QueryEngine.swift
// SwiftCodeAgent
//
// Headless query engine — takes a prompt, calls AnthropicClient, returns response.
// Mirrors the headless path in .reference/src/QueryEngine.ts
//
// This is the non-streaming, single-turn engine. The streaming multi-turn
// agent loop lives in QueryLoop.swift.

import Foundation
import SwiftCodeCore
import SwiftCodeAPI

// MARK: - AnthropicAPI Protocol

/// Protocol over AnthropicClient so the engine can be tested with a mock.
/// AnthropicClient conforms to this; test doubles also conform.
///
/// The real AnthropicClient is an actor — callers must await across the
/// actor boundary. This protocol captures both the non-streaming and
/// streaming paths used by QueryEngine and QueryLoop.
public protocol AnthropicAPI: Sendable {
    /// Non-streaming single-turn call.
    func messages(_ request: MessagesRequest) async throws -> MessagesResponse

    /// Streaming call, returning an async sequence of events.
    func messagesStream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error>
}

// Make AnthropicClient conform to the protocol.
extension AnthropicClient: AnthropicAPI {}

// MARK: - QueryEngineError

public enum QueryEngineError: Error, Sendable {
    case emptyResponse
    case invalidModel(String)
    case apiError(underlying: Error)
}

// MARK: - QueryEngine

/// Headless single-turn query engine.
///
/// For simple use cases (one prompt → one response) without tool dispatch.
/// The full multi-turn streaming loop is in QueryLoop.
///
/// Usage:
/// ```swift
/// let engine = QueryEngine(client: client)
/// let reply = try await engine.run(userMessage: "What is 2+2?")
/// print(reply.content)
/// ```
public actor QueryEngine {

    public let client: any AnthropicAPI
    public let model: String
    private let composer: SystemPromptComposer

    // MARK: Init

    public init(
        client: any AnthropicAPI,
        model: String = "claude-opus-4-6",
        composer: SystemPromptComposer = SystemPromptComposer()
    ) {
        self.client = client
        self.model = model
        self.composer = composer
    }

    // MARK: Single-Turn Query

    /// Run a single non-streaming query.
    ///
    /// - Parameters:
    ///   - userMessage:  The user's message text.
    ///   - systemPrompt: Override system prompt (nil → use default core text).
    ///   - maxTokens:    Max tokens for the response.
    /// - Returns: The assistant's response as an `AssistantMessage`.
    public func run(
        userMessage: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 4096
    ) async throws -> AssistantMessage {
        let resolvedModel = ModelRegistry.canonicalID(model) ?? model

        let systemText = systemPrompt ?? composer.coreText
        let systemBlocks = [SystemBlock(text: systemText, cacheControl: .ephemeral)]

        let apiMessages = [
            APIMessage(role: "user", content: .string(userMessage))
        ]

        let request = MessagesRequest(
            model: resolvedModel,
            maxTokens: maxTokens,
            messages: apiMessages,
            system: systemBlocks
        )

        let response = try await client.messages(request)

        guard !response.content.isEmpty else {
            throw QueryEngineError.emptyResponse
        }

        // Map response content blocks to AssistantContent
        let content: [AssistantContent] = response.content.compactMap { block in
            switch block.type {
            case "text":
                return block.text.map { .text($0) }
            case "thinking":
                if let thinking = block.thinking {
                    return .thinking(thinking: thinking, signature: block.signature ?? "")
                }
                return nil
            case "tool_use":
                if let id = block.id, let name = block.name {
                    let input = (block.input?.asObject) ?? [:]
                    return .toolUse(id: id, name: name, input: input)
                }
                return nil
            default:
                return nil
            }
        }

        let usage = Usage(
            inputTokens: response.usage.inputTokens,
            outputTokens: response.usage.outputTokens,
            cacheReadInputTokens: response.usage.cacheReadInputTokens,
            cacheCreationInputTokens: response.usage.cacheCreationInputTokens
        )

        let stopReason = response.stopReason.flatMap { StopReason(rawValue: $0) }

        return AssistantMessage(
            uuid: UUID().uuidString,
            content: content,
            usage: usage,
            stopReason: stopReason
        )
    }

    // MARK: Multi-Message Query

    /// Run a query with an existing message history.
    ///
    /// - Parameters:
    ///   - messages:     The conversation history (user + assistant turns).
    ///   - systemPrompt: Override system prompt.
    ///   - maxTokens:    Max tokens for the response.
    /// - Returns: The assistant's next response.
    public func run(
        messages: [Message],
        systemPrompt: String? = nil,
        maxTokens: Int = 4096
    ) async throws -> AssistantMessage {
        let resolvedModel = ModelRegistry.canonicalID(model) ?? model
        let systemText = systemPrompt ?? composer.coreText
        let systemBlocks = [SystemBlock(text: systemText, cacheControl: .ephemeral)]

        let apiMessages = messages.compactMap { message -> APIMessage? in
            switch message {
            case .user(let msg):
                switch msg.content {
                case .text(let t):
                    return APIMessage(role: "user", content: .string(t))
                case .toolResult(let id, let content):
                    let resultContent = content.compactMap { block -> JSONValue? in
                        if case .text(let t) = block {
                            return .object([
                                "type": .string("text"),
                                "text": .string(t)
                            ])
                        }
                        return nil
                    }
                    let toolResultBlock: JSONValue = .object([
                        "type": .string("tool_result"),
                        "tool_use_id": .string(id),
                        "content": .array(resultContent)
                    ])
                    return APIMessage(role: "user", content: .array([toolResultBlock]))
                case .image(let mediaType, let data):
                    let imageBlock: JSONValue = .object([
                        "type": .string("image"),
                        "source": .object([
                            "type": .string("base64"),
                            "media_type": .string(mediaType),
                            "data": .string(data)
                        ])
                    ])
                    return APIMessage(role: "user", content: .array([imageBlock]))
                }
            case .assistant(let msg):
                let blocks: [JSONValue] = msg.content.compactMap { block in
                    switch block {
                    case .text(let t):
                        return .object(["type": .string("text"), "text": .string(t)])
                    case .thinking(let thinking, let signature):
                        return .object([
                            "type": .string("thinking"),
                            "thinking": .string(thinking),
                            "signature": .string(signature)
                        ])
                    case .toolUse(let id, let name, let input):
                        return .object([
                            "type": .string("tool_use"),
                            "id": .string(id),
                            "name": .string(name),
                            "input": .object(input)
                        ])
                    }
                }
                return APIMessage(role: "assistant", content: .array(blocks))
            case .system, .progress:
                return nil
            }
        }

        let request = MessagesRequest(
            model: resolvedModel,
            maxTokens: maxTokens,
            messages: apiMessages,
            system: systemBlocks
        )

        let response = try await client.messages(request)

        let content: [AssistantContent] = response.content.compactMap { block in
            switch block.type {
            case "text":
                return block.text.map { .text($0) }
            case "thinking":
                if let thinking = block.thinking {
                    return .thinking(thinking: thinking, signature: block.signature ?? "")
                }
                return nil
            case "tool_use":
                if let id = block.id, let name = block.name {
                    let input = (block.input?.asObject) ?? [:]
                    return .toolUse(id: id, name: name, input: input)
                }
                return nil
            default:
                return nil
            }
        }

        let usage = Usage(
            inputTokens: response.usage.inputTokens,
            outputTokens: response.usage.outputTokens,
            cacheReadInputTokens: response.usage.cacheReadInputTokens,
            cacheCreationInputTokens: response.usage.cacheCreationInputTokens
        )

        let stopReason = response.stopReason.flatMap { StopReason(rawValue: $0) }

        return AssistantMessage(
            uuid: UUID().uuidString,
            content: content,
            usage: usage,
            stopReason: stopReason
        )
    }
}

// MARK: - JSONValue Extension

private extension JSONValue {
    var asObject: [String: JSONValue]? {
        if case .object(let dict) = self { return dict }
        return nil
    }
}
