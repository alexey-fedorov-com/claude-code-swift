// QueryLoop.swift
// SwiftCodeAgent
//
// Streaming query loop with tool orchestration hooks.
//
// Mirrors the main query loop from:
//   .reference/src/query.ts       — main streaming loop
//   .reference/src/QueryEngine.ts — headless engine loop
//   .reference/src/query/*.ts     — helper modules
//
// The loop:
//  1. Build API request from messages + system prompt
//  2. Stream SSE events from AnthropicClient
//  3. Accumulate content blocks, emit Message values
//  4. If stop_reason == "tool_use", dispatch to ToolOrchestrator
//  5. Append tool_result, loop back to step 1
//  6. If token usage exceeds threshold, run Compactor before next turn
//  7. If prompt_too_long error received, run Compactor + retry
//  8. If max_tokens stop reason, continue with same context
//
// SDK stream-json event shape details are deferred to Task 15.
// Missing tool result recovery (synthetic error responses) matches reference.

import Foundation
import SwiftCodeCore
import SwiftCodeAPI

// MARK: - QueryLoopError

public enum QueryLoopError: Error, Sendable {
    case compactionCircuitBreakerOpen(message: String)
    case promptTooLong
    case maxRetriesExceeded(attempts: Int)
    case streamInterrupted(underlying: Error)
}

// MARK: - QueryLoopEvent

/// Events emitted by the QueryLoop stream.
/// Callers can observe these to update the UI progressively.
public enum QueryLoopEvent: Sendable {
    /// A complete assistant message has been assembled.
    case assistantMessage(AssistantMessage)
    /// A tool was dispatched and this is its result.
    case toolResult(toolUseID: String, toolName: String, result: String, isError: Bool)
    /// Compaction was triggered this turn.
    case compactionTriggered
    /// The loop has completed (model said end_turn with no tool use).
    case done
    /// An unrecoverable error occurred.
    case error(QueryLoopError)
}

// MARK: - QueryLoop

/// The streaming agent loop.
///
/// Creates an `AsyncThrowingStream<QueryLoopEvent, Error>` that runs the
/// full turn-based conversation loop until the model stops requesting tools
/// or an unrecoverable error occurs.
public actor QueryLoop {

    public let client: any AnthropicAPI
    public let model: String
    public let maxTokens: Int
    public let modelContextWindow: Int

    // MARK: Init

    public init(
        client: any AnthropicAPI,
        model: String = "claude-opus-4-6",
        maxTokens: Int = 16_000,
        modelContextWindow: Int = 200_000
    ) {
        self.client = client
        self.model = model
        self.maxTokens = maxTokens
        self.modelContextWindow = modelContextWindow
    }

    // MARK: - Public Stream Entry Point

    /// Run the streaming agent loop, yielding QueryLoopEvents.
    ///
    /// - Parameters:
    ///   - messages:         The conversation history to start from.
    ///   - systemPrompt:     The composed system prompt string.
    ///   - tools:            Tool definitions to pass to the API (nil → no tools).
    ///   - toolOrchestrator: Handles tool dispatch when the model requests a tool.
    ///   - compactor:        Manages conversation compaction when context fills.
    /// - Returns: An async stream of QueryLoopEvents.
    public func stream(
        messages: [Message],
        systemPrompt: String,
        tools: [ToolDefinition]? = nil,
        toolOrchestrator: ToolOrchestrator,
        compactor: Compactor
    ) -> AsyncThrowingStream<QueryLoopEvent, Error> {
        // Capture state for the async context
        let client = self.client
        let model = self.model
        let maxTokens = self.maxTokens
        let modelContextWindow = self.modelContextWindow

        return AsyncThrowingStream { continuation in
            Task {
                var currentMessages = messages
                var turnCount = 0
                let maxTurns = 50  // safety cap

                while turnCount < maxTurns {
                    turnCount += 1

                    // Check if compaction needed before next turn
                    if shouldAutoCompact(messages: currentMessages, modelContextWindow: modelContextWindow) {
                        continuation.yield(.compactionTriggered)
                        do {
                            currentMessages = try await compactor.compact(currentMessages)
                        } catch CompactionError.circuitBreakerOpen(let msg) {
                            continuation.yield(.error(.compactionCircuitBreakerOpen(message: msg)))
                            continuation.finish()
                            return
                        } catch {
                            // Non-fatal: log and continue without compaction
                        }
                    }

                    // Build and send API request
                    let resolvedModel = ModelRegistry.canonicalID(model) ?? model
                    let systemBlocks = [SystemBlock(text: systemPrompt, cacheControl: .ephemeral)]
                    let apiMessages = Self.convertToAPIMessages(currentMessages)

                    let request = MessagesRequest(
                        model: resolvedModel,
                        maxTokens: maxTokens,
                        messages: apiMessages,
                        system: systemBlocks,
                        tools: tools
                    )

                    // Accumulate the streamed response
                    let streamResult: StreamAccumulator.Result
                    do {
                        streamResult = try await StreamAccumulator.accumulate(
                            stream: client.messagesStream(request)
                        )
                    } catch let apiError as APIError {
                        // Check for prompt_too_long (HTTP 413 / error type)
                        if case .httpError(let code, _) = apiError, code == 413 {
                            continuation.yield(.compactionTriggered)
                            do {
                                currentMessages = try await compactor.compact(currentMessages)
                                continue // retry after compaction
                            } catch CompactionError.circuitBreakerOpen(let msg) {
                                continuation.yield(.error(.compactionCircuitBreakerOpen(message: msg)))
                                continuation.finish()
                                return
                            } catch {
                                continuation.yield(.error(.promptTooLong))
                                continuation.finish()
                                return
                            }
                        }
                        continuation.finish(throwing: apiError)
                        return
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }

                    // Emit the assembled assistant message
                    let assistantMessage = streamResult.message
                    continuation.yield(.assistantMessage(assistantMessage))

                    // Append assistant turn to history
                    currentMessages.append(.assistant(assistantMessage))

                    // Determine what to do based on stop reason
                    switch assistantMessage.stopReason {
                    case .endTurn, .stopSequence, nil:
                        // Conversation complete
                        continuation.yield(.done)
                        continuation.finish()
                        return

                    case .maxTokens:
                        // Model hit max tokens — continue without adding anything
                        // The reference handles this by letting the loop re-run
                        // which appends an empty continuation. For simplicity,
                        // we stop here. Full handling deferred to Task 15.
                        continuation.yield(.done)
                        continuation.finish()
                        return

                    case .toolUse:
                        // Dispatch all tool calls and collect results
                        let toolUseBlocks = assistantMessage.content.compactMap { block -> (id: String, name: String, input: [String: JSONValue])? in
                            if case .toolUse(let id, let name, let input) = block {
                                return (id, name, input)
                            }
                            return nil
                        }

                        if toolUseBlocks.isEmpty {
                            // Model said tool_use but sent no tool blocks — recover with synthetic error
                            let syntheticResult = UserMessage(
                                uuid: UUID().uuidString,
                                content: .text("[No tool calls found despite tool_use stop reason]"),
                                isMeta: true
                            )
                            currentMessages.append(.user(syntheticResult))
                            continue
                        }

                        // Execute all tool calls (once each) and build tool_result messages.
                        // The API requires tool_result blocks to follow the tool_use turn.
                        for toolCall in toolUseBlocks {
                            let (result, isError) = await toolOrchestrator.dispatchSafe(
                                name: toolCall.name,
                                input: toolCall.input
                            )
                            continuation.yield(.toolResult(
                                toolUseID: toolCall.id,
                                toolName: toolCall.name,
                                result: result,
                                isError: isError
                            ))
                            let toolResultMsg = UserMessage(
                                uuid: UUID().uuidString,
                                content: .toolResult(
                                    id: toolCall.id,
                                    content: [.text(result)]
                                ),
                                isMeta: false
                            )
                            currentMessages.append(.user(toolResultMsg))
                        }
                        // Continue loop for next assistant turn
                    }
                }

                // Hit max turns safety cap
                continuation.yield(.error(.maxRetriesExceeded(attempts: maxTurns)))
                continuation.finish()
            }
        }
    }

    // MARK: - Message Conversion

    /// Convert the session Message array to API-format APIMessages.
    nonisolated static func convertToAPIMessages(_ messages: [Message]) -> [APIMessage] {
        messages.compactMap { message -> APIMessage? in
            switch message {
            case .user(let msg):
                return convertUserMessage(msg)
            case .assistant(let msg):
                return convertAssistantMessage(msg)
            case .system, .progress:
                return nil
            }
        }
    }

    nonisolated private static func convertUserMessage(_ msg: UserMessage) -> APIMessage {
        switch msg.content {
        case .text(let t):
            return APIMessage(role: "user", content: .string(t))
        case .toolResult(let id, let content):
            let resultContent = content.compactMap { block -> JSONValue? in
                if case .text(let t) = block {
                    return .object(["type": .string("text"), "text": .string(t)])
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
    }

    nonisolated private static func convertAssistantMessage(_ msg: AssistantMessage) -> APIMessage {
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
    }
}

// MARK: - StreamAccumulator

/// Accumulates streaming SSE events into a complete AssistantMessage.
/// Handles interleaved text and tool_use blocks.
private enum StreamAccumulator {

    struct Result {
        let message: AssistantMessage
        let inputTokens: Int
        let outputTokens: Int
    }

    static func accumulate(stream: AsyncThrowingStream<StreamEvent, Error>) async throws -> Result {
        var messageID: String = UUID().uuidString
        var textByIndex: [Int: String] = [:]
        var toolUseByIndex: [Int: (id: String, name: String, jsonBuffer: String)] = [:]
        var thinkingByIndex: [Int: (text: String, signature: String)] = [:]
        var blockTypes: [Int: String] = [:]
        var stopReason: String? = nil
        var inputTokens = 0
        var outputTokens = 0

        for try await event in stream {
            switch event {
            case .messageStart(let data):
                messageID = data.message.id
                inputTokens = data.message.usage.inputTokens ?? 0
                outputTokens = data.message.usage.outputTokens ?? 0

            case .contentBlockStart(let index, let block):
                blockTypes[index] = block.type
                switch block.type {
                case "text":
                    // Initialize with empty string; content arrives via text_delta events.
                    // The block start may carry a stub text field but deltas are the source of truth.
                    textByIndex[index] = ""
                case "tool_use":
                    if let id = block.id, let name = block.name {
                        toolUseByIndex[index] = (id: id, name: name, jsonBuffer: "")
                    }
                case "thinking":
                    thinkingByIndex[index] = (text: "", signature: "")
                default:
                    break
                }

            case .contentBlockDelta(let index, let delta):
                switch delta.type {
                case "text_delta":
                    if let text = delta.text {
                        textByIndex[index, default: ""] += text
                    }
                case "input_json_delta":
                    if let partial = delta.partialJson {
                        toolUseByIndex[index]?.jsonBuffer += partial
                    }
                case "thinking_delta":
                    if let thinking = delta.thinking {
                        thinkingByIndex[index]?.text += thinking
                    }
                case "signature_delta":
                    if let sig = delta.signature {
                        thinkingByIndex[index]?.signature += sig
                    }
                default:
                    break
                }

            case .contentBlockStop:
                break

            case .messageDelta(let delta, let usage):
                stopReason = delta.stopReason
                outputTokens = usage.outputTokens ?? outputTokens

            case .messageStop, .ping:
                break

            case .error(let err):
                throw APIError.unknown(message: err.message)
            }
        }

        // Assemble content blocks in index order
        let sortedIndices = blockTypes.keys.sorted()
        var content: [AssistantContent] = []

        for index in sortedIndices {
            let type_ = blockTypes[index]!
            switch type_ {
            case "text":
                if let text = textByIndex[index], !text.isEmpty {
                    content.append(.text(text))
                }
            case "tool_use":
                if let tool = toolUseByIndex[index] {
                    // Parse accumulated JSON buffer for tool input
                    let input: [String: JSONValue]
                    if tool.jsonBuffer.isEmpty {
                        input = [:]
                    } else {
                        input = (try? parseToolInput(tool.jsonBuffer)) ?? [:]
                    }
                    content.append(.toolUse(id: tool.id, name: tool.name, input: input))
                }
            case "thinking":
                if let thinking = thinkingByIndex[index] {
                    content.append(.thinking(thinking: thinking.text, signature: thinking.signature))
                }
            default:
                break
            }
        }

        let usage = Usage(
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )

        let message = AssistantMessage(
            uuid: messageID,
            content: content,
            usage: usage,
            stopReason: stopReason.flatMap { StopReason(rawValue: $0) }
        )

        return Result(message: message, inputTokens: inputTokens, outputTokens: outputTokens)
    }

    private static func parseToolInput(_ json: String) throws -> [String: JSONValue] {
        guard let data = json.data(using: .utf8) else { return [:] }
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .object(let dict) = decoded { return dict }
        return [:]
    }
}
