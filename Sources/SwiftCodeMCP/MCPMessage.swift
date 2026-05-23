/// MCP / JSON-RPC 2.0 message types.
///
/// The Model Context Protocol uses JSON-RPC 2.0 as its wire format.
/// Messages are newline-delimited JSON when sent over stdio transports.

import Foundation
import SwiftCodeCore

// MARK: - JSONRPCId

/// A JSON-RPC 2.0 message identifier. Can be a number, string, or null.
public enum JSONRPCId: Codable, Sendable, Hashable {
    case number(Int)
    case string(String)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Int.self) {
            self = .number(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "JSONRPCId must be int, string, or null"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - JSONRPCError

/// A JSON-RPC 2.0 error object.
public struct JSONRPCError: Codable, Sendable, Error {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // Standard JSON-RPC error codes
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603
}

// MARK: - JSONRPCRequest

/// A JSON-RPC 2.0 request (expects a response).
public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String  // "2.0"
    public let id: JSONRPCId
    public let method: String
    public let params: JSONValue?

    public init(id: JSONRPCId, method: String, params: JSONValue? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

// MARK: - JSONRPCNotification

/// A JSON-RPC 2.0 notification (no response expected).
public struct JSONRPCNotification: Codable, Sendable {
    public let jsonrpc: String  // "2.0"
    public let method: String
    public let params: JSONValue?

    public init(method: String, params: JSONValue? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }
}

// MARK: - JSONRPCResponse

/// A JSON-RPC 2.0 response.
public struct JSONRPCResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCId
    public let result: JSONValue?
    public let error: JSONRPCError?

    public init(id: JSONRPCId, result: JSONValue? = nil, error: JSONRPCError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }
}

// MARK: - MCPMessage (discriminated union)

/// A discriminated JSON-RPC message (request, response, or notification).
public enum MCPMessage: Sendable {
    case request(JSONRPCRequest)
    case response(JSONRPCResponse)
    case notification(JSONRPCNotification)

    public init(from data: Data) throws {
        let raw = try JSONDecoder().decode([String: JSONValue].self, from: data)
        // A response has no "method" but has "id"
        if case .string(let method) = raw["method"] ?? .null, !method.isEmpty, raw["method"] != nil {
            // Request or notification
            if raw["id"] != nil {
                let req = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
                self = .request(req)
            } else {
                let notif = try JSONDecoder().decode(JSONRPCNotification.self, from: data)
                self = .notification(notif)
            }
        } else if case .null = raw["method"] ?? .null, raw["method"] == nil {
            // No method field → response
            let resp = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
            self = .response(resp)
        } else {
            let resp = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
            self = .response(resp)
        }
    }

    public func encoded() throws -> Data {
        switch self {
        case .request(let r): return try JSONEncoder().encode(r)
        case .response(let r): return try JSONEncoder().encode(r)
        case .notification(let n): return try JSONEncoder().encode(n)
        }
    }
}

// MARK: - MCP Domain Types

/// An MCP tool descriptor.
public struct MCPTool: Codable, Sendable {
    public let name: String
    public let description: String?
    public let inputSchema: JSONValue?

    public init(name: String, description: String? = nil, inputSchema: JSONValue? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// Result of calling an MCP tool.
public struct ToolCallResult: Sendable {
    /// All content blocks. Never truncated (2.1.89 backport: multi-element error content).
    public let content: [MCPContentBlock]
    public let isError: Bool

    public init(content: [MCPContentBlock], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }
}

/// A single content block in a tool result.
public enum MCPContentBlock: Codable, Sendable {
    case text(String)
    case image(mimeType: String, data: String)
    case resource(uri: String, mimeType: String?, text: String?)

    private enum CodingKeys: String, CodingKey {
        case type, text, mimeType, data, uri
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try c.decode(String.self, forKey: .text))
        case "image":
            self = .image(
                mimeType: try c.decode(String.self, forKey: .mimeType),
                data: try c.decode(String.self, forKey: .data)
            )
        case "resource":
            self = .resource(
                uri: try c.decode(String.self, forKey: .uri),
                mimeType: try c.decodeIfPresent(String.self, forKey: .mimeType),
                text: try c.decodeIfPresent(String.self, forKey: .text)
            )
        default:
            self = .text("[unknown content type: \(type)]")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let v):
            try c.encode("text", forKey: .type)
            try c.encode(v, forKey: .text)
        case .image(let mime, let data):
            try c.encode("image", forKey: .type)
            try c.encode(mime, forKey: .mimeType)
            try c.encode(data, forKey: .data)
        case .resource(let uri, let mime, let text):
            try c.encode("resource", forKey: .type)
            try c.encode(uri, forKey: .uri)
            if let mime { try c.encode(mime, forKey: .mimeType) }
            if let text { try c.encode(text, forKey: .text) }
        }
    }
}

/// An MCP resource descriptor.
public struct MCPResource: Codable, Sendable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?

    public init(uri: String, name: String, description: String? = nil, mimeType: String? = nil) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
    }
}

/// Contents of a read resource.
public struct ResourceContent: Sendable {
    public let uri: String
    public let mimeType: String?
    public let text: String?
    public let blob: Data?

    public init(uri: String, mimeType: String? = nil, text: String? = nil, blob: Data? = nil) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
        self.blob = blob
    }
}

/// An MCP prompt descriptor.
public struct MCPPrompt: Codable, Sendable {
    public let name: String
    public let description: String?
    public let arguments: [MCPPromptArgument]?

    public init(name: String, description: String? = nil, arguments: [MCPPromptArgument]? = nil) {
        self.name = name
        self.description = description
        self.arguments = arguments
    }
}

/// A single argument for an MCP prompt.
public struct MCPPromptArgument: Codable, Sendable {
    public let name: String
    public let description: String?
    public let required: Bool?

    public init(name: String, description: String? = nil, required: Bool? = nil) {
        self.name = name
        self.description = description
        self.required = required
    }
}

/// The result of a getPrompt call.
public struct PromptContent: Sendable {
    public let description: String?
    public let messages: [PromptMessage]

    public init(description: String? = nil, messages: [PromptMessage]) {
        self.description = description
        self.messages = messages
    }
}

/// A single message in a prompt result.
public struct PromptMessage: Sendable {
    public let role: String  // "user" or "assistant"
    public let content: MCPContentBlock

    public init(role: String, content: MCPContentBlock) {
        self.role = role
        self.content = content
    }
}

/// Server info returned by `initialize`.
public struct InitializeResult: Sendable {
    public let protocolVersion: String
    public let serverInfo: ServerInfo
    public let capabilities: ServerCapabilities

    public init(protocolVersion: String, serverInfo: ServerInfo, capabilities: ServerCapabilities) {
        self.protocolVersion = protocolVersion
        self.serverInfo = serverInfo
        self.capabilities = capabilities
    }
}

public struct ServerInfo: Sendable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

public struct ServerCapabilities: Sendable {
    public let tools: Bool
    public let resources: Bool
    public let prompts: Bool

    public init(tools: Bool = false, resources: Bool = false, prompts: Bool = false) {
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
    }
}
