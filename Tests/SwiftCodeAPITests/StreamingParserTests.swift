import XCTest
@testable import SwiftCodeAPI

final class StreamingParserTests: XCTestCase {

    // MARK: - Single Event Tests

    func testParsePing() throws {
        var parser = SSEStreamingParser()
        let chunk = "event: ping\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        if case .ping = events[0] {} else {
            XCTFail("Expected ping event, got \(events[0])")
        }
    }

    func testParseMessageStop() throws {
        var parser = SSEStreamingParser()
        let chunk = "event: message_stop\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        if case .messageStop = events[0] {} else {
            XCTFail("Expected messageStop event, got \(events[0])")
        }
    }

    func testParseMessageStart() throws {
        var parser = SSEStreamingParser()
        // Single-line JSON — SSE `data:` must be on one line
        let json = #"{"message":{"id":"msg_abc123","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}"#
        let chunk = "event: message_start\ndata: \(json)\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        if case .messageStart(let data) = events[0] {
            XCTAssertEqual(data.message.id, "msg_abc123")
            XCTAssertEqual(data.message.role, "assistant")
            XCTAssertEqual(data.message.model, "claude-sonnet-4-6")
            XCTAssertEqual(data.message.usage.inputTokens, 10)
        } else {
            XCTFail("Expected messageStart, got \(events[0])")
        }
    }

    func testParseContentBlockStart() throws {
        var parser = SSEStreamingParser()
        let json = """
        {"index": 0, "content_block": {"type": "text", "text": ""}}
        """
        let chunk = "event: content_block_start\ndata: \(json)\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        if case .contentBlockStart(let index, let block) = events[0] {
            XCTAssertEqual(index, 0)
            XCTAssertEqual(block.type, "text")
        } else {
            XCTFail("Expected contentBlockStart, got \(events[0])")
        }
    }

    func testParseTextContentBlockDelta() throws {
        var parser = SSEStreamingParser()
        let json = """
        {"index": 0, "delta": {"type": "text_delta", "text": "Hello"}}
        """
        let chunk = "event: content_block_delta\ndata: \(json)\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        if case .contentBlockDelta(let index, let delta) = events[0] {
            XCTAssertEqual(index, 0)
            XCTAssertEqual(delta.type, "text_delta")
            XCTAssertEqual(delta.text, "Hello")
        } else {
            XCTFail("Expected contentBlockDelta, got \(events[0])")
        }
    }

    func testParseContentBlockStop() throws {
        var parser = SSEStreamingParser()
        let json = """
        {"index": 0}
        """
        let chunk = "event: content_block_stop\ndata: \(json)\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        if case .contentBlockStop(let index) = events[0] {
            XCTAssertEqual(index, 0)
        } else {
            XCTFail("Expected contentBlockStop, got \(events[0])")
        }
    }

    func testParseMessageDelta() throws {
        var parser = SSEStreamingParser()
        let json = """
        {"delta": {"stop_reason": "end_turn", "stop_sequence": null}, "usage": {"output_tokens": 25}}
        """
        let chunk = "event: message_delta\ndata: \(json)\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        if case .messageDelta(let delta, let usage) = events[0] {
            XCTAssertEqual(delta.stopReason, "end_turn")
            XCTAssertEqual(usage.outputTokens, 25)
        } else {
            XCTFail("Expected messageDelta, got \(events[0])")
        }
    }

    func testParseErrorEvent() throws {
        var parser = SSEStreamingParser()
        let json = """
        {"error": {"type": "overloaded_error", "message": "API is overloaded"}}
        """
        let chunk = "event: error\ndata: \(json)\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        if case .error(let err) = events[0] {
            XCTAssertEqual(err.type, "overloaded_error")
            XCTAssertEqual(err.message, "API is overloaded")
        } else {
            XCTFail("Expected error event, got \(events[0])")
        }
    }

    // MARK: - Tool Use Block Tests

    func testParseToolUseContentBlockStart() throws {
        var parser = SSEStreamingParser()
        let json = """
        {"index": 1, "content_block": {"type": "tool_use", "id": "toolu_01", "name": "bash"}}
        """
        let chunk = "event: content_block_start\ndata: \(json)\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        if case .contentBlockStart(let index, let block) = events[0] {
            XCTAssertEqual(index, 1)
            XCTAssertEqual(block.type, "tool_use")
            XCTAssertEqual(block.id, "toolu_01")
            XCTAssertEqual(block.name, "bash")
        } else {
            XCTFail("Expected contentBlockStart with tool_use, got \(events[0])")
        }
    }

    // MARK: - Partial Buffer Tests

    func testHandlesPartialBufferSplit() throws {
        var parser = SSEStreamingParser()

        // Split the event across two calls
        let part1 = "event: ping\n"
        let part2 = "\n"

        let events1 = try parser.feed(part1)
        XCTAssertEqual(events1.count, 0, "No complete event yet after first chunk")

        let events2 = try parser.feed(part2)
        XCTAssertEqual(events2.count, 1, "Should have one event after second chunk")
        if case .ping = events2[0] {} else {
            XCTFail("Expected ping, got \(events2[0])")
        }
    }

    func testHandlesMultipleEventsInOneChunk() throws {
        var parser = SSEStreamingParser()
        // Each event block must end with a blank line (\n\n)
        let chunk = "event: ping\n\nevent: ping\n\nevent: message_stop\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 3)
        if case .ping = events[0] {} else { XCTFail("Expected ping[0]") }
        if case .ping = events[1] {} else { XCTFail("Expected ping[1]") }
        if case .messageStop = events[2] {} else { XCTFail("Expected messageStop[2]") }
    }

    func testHandlesDataSplitAcrossChunks() throws {
        var parser = SSEStreamingParser()
        // Split in the middle of the data line
        let part1 = "event: content_block_stop\ndata: {\"in"
        let part2 = "dex\": 0}\n\n"

        let events1 = try parser.feed(part1)
        XCTAssertEqual(events1.count, 0)

        let events2 = try parser.feed(part2)
        XCTAssertEqual(events2.count, 1)
        if case .contentBlockStop(let index) = events2[0] {
            XCTAssertEqual(index, 0)
        } else {
            XCTFail("Expected contentBlockStop")
        }
    }

    // MARK: - Comment Handling

    func testIgnoresComments() throws {
        var parser = SSEStreamingParser()
        let chunk = ": this is a comment\nevent: ping\n\n"
        let events = try parser.feed(chunk)
        XCTAssertEqual(events.count, 1)
        if case .ping = events[0] {} else { XCTFail("Expected ping") }
    }

    // MARK: - Full Response Sequence

    func testFullStreamingSequence() throws {
        var parser = SSEStreamingParser()
        // Note: each SSE event block must end with a blank line (\n\n).
        // The message_stop block below ends with \n\n via the explicit trailing newline.
        let stream = "event: message_start\n"
            + "data: {\"message\": {\"id\": \"msg_1\", \"type\": \"message\", \"role\": \"assistant\", \"content\": [], \"model\": \"claude-sonnet-4-6\", \"stop_reason\": null, \"stop_sequence\": null, \"usage\": {\"input_tokens\": 5, \"output_tokens\": 0}}}\n"
            + "\n"
            + "event: content_block_start\n"
            + "data: {\"index\": 0, \"content_block\": {\"type\": \"text\", \"text\": \"\"}}\n"
            + "\n"
            + "event: content_block_delta\n"
            + "data: {\"index\": 0, \"delta\": {\"type\": \"text_delta\", \"text\": \"Hello\"}}\n"
            + "\n"
            + "event: content_block_delta\n"
            + "data: {\"index\": 0, \"delta\": {\"type\": \"text_delta\", \"text\": \" world\"}}\n"
            + "\n"
            + "event: content_block_stop\n"
            + "data: {\"index\": 0}\n"
            + "\n"
            + "event: message_delta\n"
            + "data: {\"delta\": {\"stop_reason\": \"end_turn\", \"stop_sequence\": null}, \"usage\": {\"output_tokens\": 2}}\n"
            + "\n"
            + "event: message_stop\n"
            + "\n"  // trailing blank line terminates the final event block
        let events = try parser.feed(stream)
        XCTAssertEqual(events.count, 7)

        // Verify sequence
        if case .messageStart(_) = events[0] {} else { XCTFail("Expected messageStart at [0]") }
        if case .contentBlockStart(_, _) = events[1] {} else { XCTFail("Expected contentBlockStart at [1]") }
        if case .contentBlockDelta(_, let d) = events[2] { XCTAssertEqual(d.text, "Hello") }
        else { XCTFail("Expected contentBlockDelta at [2]") }
        if case .contentBlockDelta(_, let d) = events[3] { XCTAssertEqual(d.text, " world") }
        else { XCTFail("Expected contentBlockDelta at [3]") }
        if case .contentBlockStop(0) = events[4] {} else { XCTFail("Expected contentBlockStop at [4]") }
        if case .messageDelta(_, _) = events[5] {} else { XCTFail("Expected messageDelta at [5]") }
        if case .messageStop = events[6] {} else { XCTFail("Expected messageStop at [6]") }
    }
}
