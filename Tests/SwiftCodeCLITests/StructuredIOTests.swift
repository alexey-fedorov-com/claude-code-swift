// StructuredIOTests.swift
// SwiftCodeCLITests
//
// Tests that StructuredIO produces the expected output for each format.

import Testing
import Foundation
@testable import SwiftCodeCLI
import SwiftCodeCore

// MARK: - Helpers

/// In-memory FileHandle that captures writes to a Data buffer.
final class MemoryFileHandle: @unchecked Sendable {
    private(set) var data = Data()
    private let lock = NSLock()

    func write(_ newData: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(newData)
    }

    var string: String {
        String(data: data, encoding: .utf8) ?? ""
    }
}

/// Build an `AssistantMessage` containing a single text block.
private func makeAssistantMessage(text: String) -> AssistantMessage {
    AssistantMessage(
        uuid: "test-uuid",
        content: [.text(text)],
        usage: nil,
        stopReason: .endTurn
    )
}

// MARK: - StructuredIO Output Tests

/// We can't inject a custom FileHandle into StructuredIO's write calls directly because
/// FileHandle.write() is a system method. We capture output by redirecting a real pipe.
/// For these tests we verify the output format by writing to a pipe and reading back.

@Suite("StructuredIO")
struct StructuredIOTests {

    /// Create a StructuredIO that writes to a pipe, and return (io, readPipe).
    private func makePipedIO(format: OutputFormat) -> (StructuredIO, Pipe) {
        let pipe = Pipe()
        let io = StructuredIO(format: format, output: pipe.fileHandleForWriting)
        return (io, pipe)
    }

    private func readPipe(_ pipe: Pipe) -> String {
        pipe.fileHandleForWriting.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Text Format

    @Test("text format: writeMessage prints plain text + newline")
    func testTextFormatMessage() throws {
        let (io, pipe) = makePipedIO(format: .text)
        let msg = makeAssistantMessage(text: "Hello, world!")
        try io.writeMessage(msg)
        let output = readPipe(pipe)
        #expect(output == "Hello, world!\n")
    }

    @Test("text format: writeError prints error line")
    func testTextFormatError() throws {
        let (io, pipe) = makePipedIO(format: .text)
        struct TestError: Error { let msg: String }
        try io.writeError(TestError(msg: "something broke"))
        let output = readPipe(pipe)
        #expect(output.hasPrefix("Error:"))
    }

    @Test("text format: writeTextDelta writes raw text without newline")
    func testTextFormatDelta() throws {
        let (io, pipe) = makePipedIO(format: .text)
        try io.writeTextDelta("chunk1")
        try io.writeTextDelta("chunk2")
        let output = readPipe(pipe)
        #expect(output == "chunk1chunk2")
    }

    // MARK: - JSON Format

    @Test("json format: writeMessage produces valid JSON with role + content")
    func testJsonFormatMessage() throws {
        let (io, pipe) = makePipedIO(format: .json)
        let msg = makeAssistantMessage(text: "JSON response")
        try io.writeMessage(msg)
        let output = readPipe(pipe)

        // Should be valid JSON
        let data = output.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil, "Output should be valid JSON")
        #expect(parsed?["role"] as? String == "assistant")

        let content = parsed?["content"] as? [[String: Any]]
        #expect(content?.first?["type"] as? String == "text")
        #expect(content?.first?["text"] as? String == "JSON response")
    }

    @Test("json format: writeError produces JSON with error key")
    func testJsonFormatError() throws {
        let (io, pipe) = makePipedIO(format: .json)
        struct E: Error, CustomStringConvertible {
            var description: String { "test-error" }
        }
        try io.writeError(E())
        let output = readPipe(pipe)
        let data = output.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["error"] != nil)
    }

    @Test("json format: writeTextDelta is no-op (buffered until writeMessage)")
    func testJsonFormatDeltaIsNoop() throws {
        let (io, pipe) = makePipedIO(format: .json)
        try io.writeTextDelta("should not appear yet")
        let output = readPipe(pipe)
        #expect(output.isEmpty)
    }

    // MARK: - stream-json Format

    @Test("stream-json format: writeMessage emits one JSON line with type=message")
    func testStreamJsonFormatMessage() throws {
        let (io, pipe) = makePipedIO(format: .streamJSON)
        let msg = makeAssistantMessage(text: "streamed content")
        try io.writeMessage(msg)
        let output = readPipe(pipe)

        // Should be JSONL (one JSON object per line)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(!lines.isEmpty)

        let firstLine = String(lines[0])
        let data = firstLine.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["type"] as? String == "message")
    }

    @Test("stream-json format: writeTextDelta emits type=text event per chunk")
    func testStreamJsonFormatDelta() throws {
        let (io, pipe) = makePipedIO(format: .streamJSON)
        try io.writeTextDelta("part1")
        try io.writeTextDelta("part2")
        let output = readPipe(pipe)

        let lines = output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        #expect(lines.count == 2)

        for line in lines {
            let data = line.data(using: .utf8)!
            let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(parsed?["type"] as? String == "text")
            let content = parsed?["content"] as? String
            #expect(content?.hasPrefix("part") == true)
        }
    }

    @Test("stream-json format: writeSessionStart emits session_start event")
    func testStreamJsonSessionStart() throws {
        let (io, pipe) = makePipedIO(format: .streamJSON)
        try io.writeSessionStart(sessionId: "abc-123")
        let output = readPipe(pipe)

        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(!lines.isEmpty)

        let firstLine = String(lines[0])
        let data = firstLine.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["type"] as? String == "session_start")
        #expect(parsed?["session_id"] as? String == "abc-123")
    }

    // MARK: - OutputFormat Parsing

    @Test("OutputFormat.parse recognizes all formats")
    func testOutputFormatParse() {
        #expect(OutputFormat.parse("text") == .text)
        #expect(OutputFormat.parse("json") == .json)
        #expect(OutputFormat.parse("stream-json") == .streamJSON)
        #expect(OutputFormat.parse("TEXT") == .text)
        #expect(OutputFormat.parse("unknown") == nil)
    }

    @Test("OutputFormat rawValues are correct")
    func testOutputFormatRawValues() {
        #expect(OutputFormat.text.rawValue == "text")
        #expect(OutputFormat.json.rawValue == "json")
        #expect(OutputFormat.streamJSON.rawValue == "stream-json")
    }
}
