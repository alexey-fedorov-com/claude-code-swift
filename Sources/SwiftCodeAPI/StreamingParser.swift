import Foundation

// MARK: - StreamEvent

/// Events emitted by the Anthropic SSE streaming API.
/// Matches the TypeScript SDK's event types in @anthropic-ai/sdk stream types.
public enum StreamEvent: Sendable {
    case messageStart(MessageStartData)
    case contentBlockStart(index: Int, contentBlock: StreamContentBlock)
    case contentBlockDelta(index: Int, delta: ContentDelta)
    case contentBlockStop(index: Int)
    case messageDelta(delta: MessageDeltaData, usage: StreamUsage)
    case messageStop
    case ping
    case error(StreamError)
}

// MARK: - Supporting Types

public struct MessageStartData: Sendable, Decodable {
    public let message: StreamMessage
}

public struct StreamMessage: Sendable, Decodable {
    public let id: String
    public let type: String
    public let role: String
    public let content: [StreamContentBlock]
    public let model: String
    public let stopReason: String?
    public let stopSequence: String?
    public let usage: StreamUsage

    private enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

public struct StreamContentBlock: Sendable, Decodable {
    public let type: String
    public let text: String?
    public let id: String?
    public let name: String?
    public let thinking: String?

    public init(type: String, text: String? = nil, id: String? = nil, name: String? = nil, thinking: String? = nil) {
        self.type = type
        self.text = text
        self.id = id
        self.name = name
        self.thinking = thinking
    }
}

public struct ContentDelta: Sendable, Decodable {
    public let type: String
    public let text: String?
    public let partialJson: String?
    public let thinking: String?
    public let signature: String?

    private enum CodingKeys: String, CodingKey {
        case type, text, thinking, signature
        case partialJson = "partial_json"
    }

    public init(type: String, text: String? = nil, partialJson: String? = nil, thinking: String? = nil, signature: String? = nil) {
        self.type = type
        self.text = text
        self.partialJson = partialJson
        self.thinking = thinking
        self.signature = signature
    }
}

public struct MessageDeltaData: Sendable, Decodable {
    public let stopReason: String?
    public let stopSequence: String?

    private enum CodingKeys: String, CodingKey {
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

public struct StreamUsage: Sendable, Decodable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let cacheCreationInputTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
    }

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
    }
}

public struct StreamError: Sendable, Decodable {
    public let type: String
    public let message: String
}

// MARK: - SSEParserError

public enum SSEParserError: Error, Sendable {
    case invalidEventFormat(String)
    case jsonDecoding(String, underlying: Error)
    case unknownEventType(String)
}

// MARK: - SSEStreamingParser

/// Stateful SSE (Server-Sent Events) parser for the Anthropic streaming API.
///
/// Protocol: each event is a sequence of `event: <type>` and `data: <json>` lines
/// separated by blank lines. `ping` events have no data line.
///
/// Handles:
/// - Complete events spanning multiple lines
/// - Partial buffers (split across HTTP chunks)
/// - Comments (lines starting with `:`)
/// - Ping-only events
public struct SSEStreamingParser: Sendable {

    // MARK: State

    /// Pending bytes that have not yet formed a complete line.
    private var buffer: String = ""

    /// Current event being assembled (between blank lines).
    private var currentEventType: String? = nil
    private var currentData: String? = nil

    // MARK: Init

    public init() {}

    // MARK: - Public Interface

    /// Feed raw bytes (an HTTP chunk) into the parser.
    /// Returns zero or more complete `StreamEvent` values.
    public mutating func feed(_ chunk: String) throws -> [StreamEvent] {
        buffer += chunk
        return try flush()
    }

    /// Feed raw bytes.
    public mutating func feed(_ bytes: [UInt8]) throws -> [StreamEvent] {
        guard let string = String(bytes: bytes, encoding: .utf8) else {
            return []
        }
        return try feed(string)
    }

    /// Signal end-of-stream. Returns any final pending event (rare).
    public mutating func finish() throws -> [StreamEvent] {
        if !buffer.isEmpty {
            buffer += "\n\n"  // force flush
            return try flush()
        }
        return []
    }

    // MARK: Private

    /// Process as many complete lines as possible from the buffer.
    private mutating func flush() throws -> [StreamEvent] {
        var events: [StreamEvent] = []

        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
            buffer = String(buffer[newlineRange.upperBound...])

            // Strip trailing \r (handle \r\n)
            let stripped = line.hasSuffix("\r") ? String(line.dropLast()) : line

            if let event = try processLine(stripped) {
                events.append(event)
            }
        }

        return events
    }

    /// Process a single decoded line. Returns an event only when a blank line
    /// completes the current event block.
    private mutating func processLine(_ line: String) throws -> StreamEvent? {
        if line.isEmpty {
            // Blank line → dispatch accumulated event
            return try dispatchEvent()
        }

        if line.hasPrefix(":") {
            // Comment — ignore
            return nil
        }

        if line.hasPrefix("event: ") {
            currentEventType = String(line.dropFirst("event: ".count))
            return nil
        }

        if line.hasPrefix("data: ") {
            let data = String(line.dropFirst("data: ".count))
            if let existing = currentData {
                currentData = existing + "\n" + data
            } else {
                currentData = data
            }
            return nil
        }

        // Other field types (id:, retry:) — ignore for now
        return nil
    }

    /// Build and return the assembled event, then reset state.
    private mutating func dispatchEvent() throws -> StreamEvent? {
        defer {
            currentEventType = nil
            currentData = nil
        }

        guard let eventType = currentEventType else {
            // No event type yet — could be a partial or empty block
            return nil
        }

        switch eventType {
        case "ping":
            return .ping

        case "message_stop":
            return .messageStop

        case "message_start":
            guard let data = currentData else {
                throw SSEParserError.invalidEventFormat("message_start missing data")
            }
            let decoded = try decodeJSON(MessageStartData.self, from: data, event: eventType)
            return .messageStart(decoded)

        case "content_block_start":
            guard let data = currentData else {
                throw SSEParserError.invalidEventFormat("content_block_start missing data")
            }
            let raw = try decodeJSON(ContentBlockStartRaw.self, from: data, event: eventType)
            return .contentBlockStart(index: raw.index, contentBlock: raw.contentBlock)

        case "content_block_delta":
            guard let data = currentData else {
                throw SSEParserError.invalidEventFormat("content_block_delta missing data")
            }
            let raw = try decodeJSON(ContentBlockDeltaRaw.self, from: data, event: eventType)
            return .contentBlockDelta(index: raw.index, delta: raw.delta)

        case "content_block_stop":
            guard let data = currentData else {
                throw SSEParserError.invalidEventFormat("content_block_stop missing data")
            }
            let raw = try decodeJSON(ContentBlockStopRaw.self, from: data, event: eventType)
            return .contentBlockStop(index: raw.index)

        case "message_delta":
            guard let data = currentData else {
                throw SSEParserError.invalidEventFormat("message_delta missing data")
            }
            let raw = try decodeJSON(MessageDeltaRaw.self, from: data, event: eventType)
            return .messageDelta(delta: raw.delta, usage: raw.usage)

        case "error":
            guard let data = currentData else {
                throw SSEParserError.invalidEventFormat("error missing data")
            }
            let decoded = try decodeJSON(StreamErrorRaw.self, from: data, event: eventType)
            return .error(decoded.error)

        default:
            // Unknown event — silently skip, don't break the stream
            return nil
        }
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from string: String, event: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw SSEParserError.invalidEventFormat("invalid UTF-8 in \(event)")
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw SSEParserError.jsonDecoding(event, underlying: error)
        }
    }
}

// MARK: - Private Decoding Helpers

private struct ContentBlockStartRaw: Decodable {
    let index: Int
    let contentBlock: StreamContentBlock

    private enum CodingKeys: String, CodingKey {
        case index
        case contentBlock = "content_block"
    }
}

private struct ContentBlockDeltaRaw: Decodable {
    let index: Int
    let delta: ContentDelta
}

private struct ContentBlockStopRaw: Decodable {
    let index: Int
}

private struct MessageDeltaRaw: Decodable {
    let delta: MessageDeltaData
    let usage: StreamUsage
}

private struct StreamErrorRaw: Decodable {
    let error: StreamError
}
