/// LSP / JSON-RPC 2.0 message types.
///
/// The Language Server Protocol uses JSON-RPC 2.0 with a Content-Length
/// HTTP-style header framing:
///
///     Content-Length: <byteCount>\r\n
///     \r\n
///     <JSON body>

import Foundation

// MARK: - LSPId (JSON-RPC id)

/// A JSON-RPC 2.0 message identifier.
public enum LSPId: Codable, Sendable, Hashable {
    case number(Int)
    case string(String)
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let v = try? c.decode(Int.self) {
            self = .number(v)
        } else if let v = try? c.decode(String.self) {
            self = .string(v)
        } else {
            throw DecodingError.dataCorruptedError(
                in: c,
                debugDescription: "LSPId must be int, string, or null"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

// MARK: - LSPError

public struct LSPError: Codable, Sendable, Error {
    public let code: Int
    public let message: String
    public let data: AnyCodable?

    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // Standard LSP error codes
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603
    public static let serverNotInitialized = -32002
    public static let requestCancelled = -32800
}

// MARK: - AnyCodable

/// Wraps any JSON-encodable value for LSP params/result fields.
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any?

    public init(_ value: Any?) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self.value = nil
        } else if let v = try? c.decode(Bool.self) {
            self.value = v
        } else if let v = try? c.decode(Int.self) {
            self.value = v
        } else if let v = try? c.decode(Double.self) {
            self.value = v
        } else if let v = try? c.decode(String.self) {
            self.value = v
        } else if let v = try? c.decode([AnyCodable].self) {
            self.value = v.map { $0.value }
        } else if let v = try? c.decode([String: AnyCodable].self) {
            self.value = v.mapValues { $0.value }
        } else {
            self.value = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case nil: try c.encodeNil()
        case let v as Bool: try c.encode(v)
        case let v as Int: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        case let v as [Any?]:
            try c.encode(v.map { AnyCodable($0) })
        case let v as [String: Any?]:
            try c.encode(v.mapValues { AnyCodable($0) })
        default: try c.encodeNil()
        }
    }
}

// MARK: - LSPRequest

public struct LSPRequest: Codable, Sendable {
    public let jsonrpc: String  // "2.0"
    public let id: LSPId
    public let method: String
    public let params: AnyCodable?

    public init(id: LSPId, method: String, params: AnyCodable? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

// MARK: - LSPNotification

public struct LSPNotification: Codable, Sendable {
    public let jsonrpc: String  // "2.0"
    public let method: String
    public let params: AnyCodable?

    public init(method: String, params: AnyCodable? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }
}

// MARK: - LSPResponse

public struct LSPResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: LSPId
    public let result: AnyCodable?
    public let error: LSPError?

    public init(id: LSPId, result: AnyCodable? = nil, error: LSPError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }
}

// MARK: - LSP Framing

/// Content-Length framing for LSP messages.
public enum LSPFraming {

    private static let separator = "\r\n\r\n"
    private static let headerPrefix = "Content-Length: "

    /// Wrap a JSON body in a Content-Length frame.
    public static func frame(_ body: Data) -> Data {
        let header = "\(headerPrefix)\(body.count)\(separator)"
        var result = header.data(using: .utf8)!
        result.append(body)
        return result
    }

    /// Parse a Content-Length frame. Returns (body, remainder) or nil if incomplete.
    public static func parse(buffer: inout Data) -> Data? {
        // Find the \r\n\r\n separator
        guard let sepData = separator.data(using: .utf8),
              let range = buffer.range(of: sepData) else { return nil }

        // Extract header
        let headerData = buffer[..<range.lowerBound]
        guard let header = String(data: headerData, encoding: .utf8) else { return nil }

        // Find Content-Length
        var contentLength: Int? = nil
        for line in header.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                contentLength = Int(value)
                break
            }
        }

        guard let length = contentLength else { return nil }

        let bodyStart = range.upperBound
        let bodyEnd = buffer.index(bodyStart, offsetBy: length, limitedBy: buffer.endIndex) ?? buffer.endIndex
        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= length else { return nil }

        let body = Data(buffer[bodyStart..<bodyEnd])
        buffer = Data(buffer[bodyEnd...])
        return body
    }
}
