// PrintModeParityTests.swift
// SwiftCodeCLITests
//
// Tests that PrintMode produces correct output for each OutputFormat.
// Uses a scripted AnthropicAPI mock (same pattern as QueryLoopTests).

import Testing
import Foundation
@testable import SwiftCodeCLI
import SwiftCodeCore
import SwiftCodeAPI
import SwiftCodeAgent

// MARK: - ScriptedClient (mirrored from SwiftCodeAgentTests)

/// Minimal scripted API client for print-mode tests.
/// Returns pre-canned responses without hitting the network.
final class PrintModeScriptedClient: AnthropicAPI, @unchecked Sendable {

    private let responses: [MessagesResponse]
    private let lock = NSLock()
    private var callIndex = 0

    init(responses: [MessagesResponse]) {
        self.responses = responses
    }

    private func next() -> MessagesResponse? {
        lock.lock(); defer { lock.unlock() }
        guard callIndex < responses.count else { return nil }
        let r = responses[callIndex]
        callIndex += 1
        return r
    }

    func messages(_ request: MessagesRequest) async throws -> MessagesResponse {
        guard let r = next() else {
            throw APIError.unknown(message: "No more scripted responses")
        }
        return r
    }

    nonisolated func messagesStream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        guard let r = next() else {
            return AsyncThrowingStream { $0.finish(throwing: APIError.unknown(message: "No more scripted responses")) }
        }
        let response = r
        return AsyncThrowingStream { continuation in
            let startData = MessageStartData(message: StreamMessage(
                id: response.id,
                model: response.model,
                usage: StreamUsage(inputTokens: response.usage.inputTokens, outputTokens: 0)
            ))
            continuation.yield(.messageStart(startData))
            for (i, block) in response.content.enumerated() {
                let cb = StreamContentBlock(type: block.type, text: block.text, id: block.id, name: block.name)
                continuation.yield(.contentBlockStart(index: i, contentBlock: cb))
                if let text = block.text, !text.isEmpty {
                    continuation.yield(.contentBlockDelta(index: i, delta: ContentDelta(type: "text_delta", text: text)))
                }
                continuation.yield(.contentBlockStop(index: i))
            }
            continuation.yield(.messageDelta(
                delta: MessageDeltaData(stopReason: response.stopReason),
                usage: StreamUsage(outputTokens: response.usage.outputTokens)
            ))
            continuation.yield(.messageStop)
            continuation.finish()
        }
    }
}

// MARK: - Response builder

private func makeResponse(text: String) -> MessagesResponse {
    MessagesResponse(
        id: "msg_test",
        type: "message",
        role: "assistant",
        content: [ContentBlock(type: "text", text: text)],
        model: "claude-opus-4-6",
        stopReason: "end_turn",
        stopSequence: nil,
        usage: UsageResponse(inputTokens: 10, outputTokens: 5)
    )
}

// MARK: - Helpers to run PrintMode with captured output

/// Run PrintMode with a scripted client by injecting via QueryEngine.
/// We can't inject directly into PrintMode.run() (it creates the client internally),
/// so we test the formatting layer via StructuredIO with a captured pipe.
private func runPrintModeFormat(
    text: String,
    format: OutputFormat
) throws -> String {
    let pipe = Pipe()
    let io = StructuredIO(format: format, output: pipe.fileHandleForWriting)

    let message = AssistantMessage(
        uuid: "u1",
        content: [.text(text)],
        usage: Usage(inputTokens: 10, outputTokens: 5),
        stopReason: .endTurn
    )

    try io.writeMessage(message)
    pipe.fileHandleForWriting.closeFile()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

// MARK: - Tests

@Suite("PrintMode parity")
struct PrintModeParityTests {

    @Test("text mode: echoes assistant message as plain text")
    func testTextModeOutput() throws {
        let output = try runPrintModeFormat(text: "The answer is 42.", format: .text)
        #expect(output == "The answer is 42.\n")
    }

    @Test("text mode: multi-line content preserved")
    func testTextModeMultiLine() throws {
        let content = "Line one.\nLine two."
        let output = try runPrintModeFormat(text: content, format: .text)
        #expect(output.contains("Line one."))
        #expect(output.contains("Line two."))
    }

    @Test("json mode: emits valid JSON with role=assistant and content array")
    func testJsonModeOutput() throws {
        let output = try runPrintModeFormat(text: "Hello!", format: .json)
        let data = output.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil, "JSON mode must produce valid JSON")
        #expect(parsed?["role"] as? String == "assistant")
        let content = parsed?["content"] as? [[String: Any]]
        #expect(content?.count == 1)
        #expect(content?.first?["type"] as? String == "text")
        #expect(content?.first?["text"] as? String == "Hello!")
    }

    @Test("stream-json mode: emits type=message line with content")
    func testStreamJsonModeMessage() throws {
        let output = try runPrintModeFormat(text: "Streaming!", format: .streamJSON)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        #expect(!lines.isEmpty)
        // Find the message-type line
        let messageLine = lines.first { line in
            if let d = line.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                return obj["type"] as? String == "message"
            }
            return false
        }
        #expect(messageLine != nil, "stream-json must include a type=message event")
    }

    @Test("stream-json mode: session_start emitted before content")
    func testStreamJsonSessionStart() throws {
        let pipe = Pipe()
        let io = StructuredIO(format: .streamJSON, output: pipe.fileHandleForWriting)
        try io.writeSessionStart(sessionId: "sess-001")
        let msg = AssistantMessage(uuid: "u1", content: [.text("hi")], usage: nil, stopReason: .endTurn)
        try io.writeMessage(msg)
        pipe.fileHandleForWriting.closeFile()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        // First line should be session_start
        let firstParsed = try JSONSerialization.jsonObject(with: lines[0].data(using: .utf8)!) as? [String: Any]
        #expect(firstParsed?["type"] as? String == "session_start")
        #expect(firstParsed?["session_id"] as? String == "sess-001")
    }

    @Test("stream-json mode: multiple text deltas appear as separate events")
    func testStreamJsonMultipleDeltas() throws {
        let pipe = Pipe()
        let io = StructuredIO(format: .streamJSON, output: pipe.fileHandleForWriting)
        try io.writeTextDelta("chunk-A")
        try io.writeTextDelta("chunk-B")
        try io.writeTextDelta("chunk-C")
        pipe.fileHandleForWriting.closeFile()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 3, "Should emit 3 separate JSONL events for 3 deltas")
    }

    // MARK: - PrintMode.run with scripted engine (integration-style)

    @Test("PrintMode.run returns 1 for empty prompt")
    func testEmptyPromptReturns1() async {
        // We can't inject a client into PrintMode.run easily, but we can test edge cases
        // by verifying that empty prompt returns exit code 1.
        // We use a real (but empty) API key — it will fail at network level,
        // but the empty-prompt check happens first.
        let code = await PrintMode.run(
            prompt: "",
            outputFormat: .text,
            model: "claude-opus-4-6"
        )
        #expect(code == 1)
    }

    @Test("OutputFormat allCases covers text, json, stream-json")
    func testAllCases() {
        let names = OutputFormat.allCases.map(\.rawValue)
        #expect(names.contains("text"))
        #expect(names.contains("json"))
        #expect(names.contains("stream-json"))
    }
}
