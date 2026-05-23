// StructuredIO.swift
// SwiftCodeCLI
//
// Handles output formatting for --output-format text / json / stream-json.
// Mirrors the structured output path in the TypeScript reference.

import Foundation
import SwiftCodeCore
import SwiftCodeAPI

// MARK: - OutputFormat

public enum OutputFormat: String, Sendable, CaseIterable {
    case text
    case json
    case streamJSON = "stream-json"

    /// Parse from a raw string (case-insensitive, hyphen-tolerant).
    public static func parse(_ raw: String) -> OutputFormat? {
        let normalized = raw.lowercased()
        return OutputFormat.allCases.first { $0.rawValue == normalized }
    }
}

// MARK: - StructuredIOError

public enum StructuredIOError: Error, Sendable {
    case encodingFailure(String)
    case writeFailed
}

// MARK: - StreamJsonEvent
// Lightweight event envelope for --output-format stream-json.
// Each line is one JSON object: { "type": "...", ... }

public struct StreamJsonEvent: Encodable, Sendable {
    public let type: String
    // text response chunks
    public let content: String?
    // assistant message (json mode)
    public let message: AssistantMessageEnvelope?
    // error
    public let error: String?

    public init(type: String, content: String? = nil, message: AssistantMessageEnvelope? = nil, error: String? = nil) {
        self.type = type
        self.content = content
        self.message = message
        self.error = error
    }
}

public struct AssistantMessageEnvelope: Encodable, Sendable {
    public let role: String
    public let content: [ContentBlockEnvelope]

    public init(role: String = "assistant", content: [ContentBlockEnvelope]) {
        self.role = role
        self.content = content
    }
}

public struct ContentBlockEnvelope: Encodable, Sendable {
    public let type: String
    public let text: String?

    public init(type: String, text: String? = nil) {
        self.type = type
        self.text = text
    }
}

// MARK: - StructuredIO

/// Writes formatted output according to the chosen OutputFormat.
/// Injecting a FileHandle lets tests capture output without touching stdout.
public struct StructuredIO: Sendable {

    public let format: OutputFormat
    private let output: FileHandle

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    public init(format: OutputFormat, output: FileHandle = .standardOutput) {
        self.format = format
        self.output = output
    }

    // MARK: - Public API

    /// Write a completed assistant message to output.
    public func writeMessage(_ message: AssistantMessage) throws {
        switch format {
        case .text:
            let text = message.content.compactMap { block -> String? in
                if case .text(let t) = block { return t }
                return nil
            }.joined()
            writeLine(text)

        case .json:
            let blocks = message.content.compactMap { block -> ContentBlockEnvelope? in
                if case .text(let t) = block {
                    return ContentBlockEnvelope(type: "text", text: t)
                }
                return nil
            }
            let wrapper = MessageWrapper(role: "assistant", content: blocks)
            try writeJSON(wrapper)

        case .streamJSON:
            // In stream-json mode, we emit a message_stop event for completed messages.
            let blocks = message.content.compactMap { block -> ContentBlockEnvelope? in
                if case .text(let t) = block {
                    return ContentBlockEnvelope(type: "text", text: t)
                }
                return nil
            }
            let envelope = AssistantMessageEnvelope(content: blocks)
            let event = StreamJsonEvent(type: "message", message: envelope)
            try writeJSONLine(event)
        }
    }

    /// Write a streaming text delta (only meaningful for stream-json).
    public func writeTextDelta(_ text: String) throws {
        switch format {
        case .text:
            // For text format in streaming, write incrementally without newline
            writeRaw(text)
        case .json:
            // Buffer; don't emit until writeMessage is called
            break
        case .streamJSON:
            let event = StreamJsonEvent(type: "text", content: text)
            try writeJSONLine(event)
        }
    }

    /// Write an error to output.
    public func writeError(_ error: Error) throws {
        let msg = "\(error)"
        switch format {
        case .text:
            writeLine("Error: \(msg)")
        case .json:
            let wrapper = ErrorWrapper(error: msg)
            try writeJSON(wrapper)
        case .streamJSON:
            let event = StreamJsonEvent(type: "error", error: msg)
            try writeJSONLine(event)
        }
    }

    /// Emit a stream-json start-of-session event.
    public func writeSessionStart(sessionId: String) throws {
        guard format == .streamJSON else { return }
        let event = SessionStartEvent(type: "session_start", sessionId: sessionId)
        try writeJSONLine(event)
    }

    // MARK: - Private helpers

    private func writeLine(_ string: String) {
        writeRaw(string + "\n")
    }

    private func writeRaw(_ string: String) {
        let data = Data(string.utf8)
        output.write(data)
    }

    private func writeJSON<T: Encodable>(_ value: T) throws {
        let data = try StructuredIO.encoder.encode(value)
        guard let str = String(data: data, encoding: .utf8) else {
            throw StructuredIOError.encodingFailure("UTF-8 conversion failed")
        }
        writeLine(str)
    }

    private func writeJSONLine<T: Encodable>(_ value: T) throws {
        try writeJSON(value)
    }
}

// MARK: - Private Codable wrappers

private struct MessageWrapper: Encodable {
    let role: String
    let content: [ContentBlockEnvelope]
}

private struct ErrorWrapper: Encodable {
    let error: String
}

private struct SessionStartEvent: Encodable {
    let type: String
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
    }
}
