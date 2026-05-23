/// TelemetryEvent — Codable telemetry event shapes.
///
/// All events must be Codable for serialisation to disk (diagnostic log)
/// and eventual transport to a telemetry sink.
///
/// Mirrors event shapes from `src/utils/log.ts` and `src/utils/telemetry.ts`.

import Foundation

// MARK: - TelemetryEvent

public struct TelemetryEvent: Codable, Sendable {
    // MARK: - Core fields

    /// Event name / type identifier (e.g. "session.start", "tool.call", "error").
    public let name: String
    /// ISO-8601 timestamp.
    public let timestamp: Date
    /// Session ID this event belongs to.
    public let sessionID: String?
    /// Payload — arbitrary key-value pairs (string-encoded values for Codable compatibility).
    public let properties: [String: AnyCodable]
    /// Privacy level this event was captured at.
    public let privacyLevel: PrivacyLevel

    public init(
        name: String,
        sessionID: String? = nil,
        properties: [String: AnyCodable] = [:],
        privacyLevel: PrivacyLevel = .full,
        timestamp: Date = Date()
    ) {
        self.name = name
        self.sessionID = sessionID
        self.properties = properties
        self.privacyLevel = privacyLevel
        self.timestamp = timestamp
    }
}

// MARK: - PrivacyLevel

public enum PrivacyLevel: String, Codable, Comparable, Sendable {
    /// Telemetry is completely disabled.
    case off
    /// Only aggregate / non-identifying events (error counts, latencies).
    case minimal
    /// Full event stream including session IDs and tool names.
    case full

    public static func < (lhs: PrivacyLevel, rhs: PrivacyLevel) -> Bool {
        order(lhs) < order(rhs)
    }

    private static func order(_ level: PrivacyLevel) -> Int {
        switch level { case .off: return 0; case .minimal: return 1; case .full: return 2 }
    }
}

// MARK: - Known event names

public enum TelemetryEventName {
    public static let sessionStart = "session.start"
    public static let sessionEnd = "session.end"
    public static let queryStart = "query.start"
    public static let queryEnd = "query.end"
    public static let toolCall = "tool.call"
    public static let toolResult = "tool.result"
    public static let error = "error"
    public static let compaction = "compaction"
    public static let permissionRequest = "permission.request"
    public static let permissionDecision = "permission.decision"
    public static let modelSwitch = "model.switch"
    public static let costUpdate = "cost.update"
    public static let voiceStart = "voice.start"
    public static let voiceEnd = "voice.end"
}

// MARK: - AnyCodable

/// Type-erased Codable wrapper for heterogeneous event properties.
public struct AnyCodable: Codable, Sendable, Equatable {
    public let value: Sendable & Equatable

    public init(_ value: some Codable & Sendable & Equatable) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { value = v }
        else if let v = try? c.decode(Double.self) { value = v }
        else if let v = try? c.decode(Bool.self) { value = v }
        else if let v = try? c.decode(Int.self) { value = v }
        else { value = "" }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as String: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as Bool:   try c.encode(v)
        case let v as Int:    try c.encode(v)
        default:              try c.encode(String(describing: value))
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Best-effort equality via description
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}

// MARK: - Convenience constructors

extension TelemetryEvent {
    public static func sessionStart(sessionID: String) -> TelemetryEvent {
        TelemetryEvent(name: TelemetryEventName.sessionStart, sessionID: sessionID, privacyLevel: .minimal)
    }

    public static func error(_ message: String, sessionID: String? = nil) -> TelemetryEvent {
        TelemetryEvent(
            name: TelemetryEventName.error,
            sessionID: sessionID,
            properties: ["message": AnyCodable(message)],
            privacyLevel: .minimal
        )
    }

    public static func toolCall(name: String, sessionID: String?) -> TelemetryEvent {
        TelemetryEvent(
            name: TelemetryEventName.toolCall,
            sessionID: sessionID,
            properties: ["tool": AnyCodable(name)],
            privacyLevel: .full
        )
    }
}
