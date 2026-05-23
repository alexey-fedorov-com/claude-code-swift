/// Generic JSON-RPC 2.0 client for MCP.
///
/// Sends requests, awaits responses, dispatches notifications.
/// Built on top of a `Transport` implementation (stdio, HTTP, SSE).

import Foundation
import SwiftCodeCore

// MARK: - MCPClientError

public enum MCPClientError: Error, Sendable {
    case notInitialized
    case serverError(JSONRPCError)
    case decodingError(String)
    case timeout
    case closed
}

// MARK: - MCPClient

/// Actor-isolated JSON-RPC 2.0 client for communicating with an MCP server.
public actor MCPClient {

    // MARK: State

    private let transport: any Transport
    private var nextId: Int = 1
    private var pendingRequests: [JSONRPCId: CheckedContinuation<JSONValue, Error>] = [:]
    private var isRunning = false
    private var initialized = false

    // Configurable timeouts (2.1.89 backport: MCP_CONNECTION_NONBLOCKING)
    private var requestTimeout: TimeInterval

    // MARK: Init

    public init(transport: any Transport) {
        self.transport = transport
        // NonblockingConnection: 5s when env var set, else 30s
        let nonblocking = ProcessInfo.processInfo.environment["MCP_CONNECTION_NONBLOCKING"] == "true"
        self.requestTimeout = nonblocking ? 5.0 : 30.0
    }

    // MARK: Lifecycle

    /// Start the transport and launch the receive loop.
    public func start() async throws {
        try await transport.start()
        isRunning = true
        startReceiveLoop()
    }

    /// Send the MCP initialize handshake.
    public func initialize(
        clientName: String = "SwiftCode",
        clientVersion: String = "1.0",
        protocolVersion: String = "2024-11-05"
    ) async throws -> InitializeResult {
        let params: JSONValue = .object([
            "protocolVersion": .string(protocolVersion),
            "clientInfo": .object([
                "name": .string(clientName),
                "version": .string(clientVersion)
            ]),
            "capabilities": .object([
                "roots": .object(["listChanged": .bool(true)]),
                "sampling": .object([:])
            ])
        ])
        let result = try await send(method: "initialize", params: params)
        initialized = true

        // Send initialized notification
        let notif = JSONRPCNotification(method: "notifications/initialized")
        let data = try JSONEncoder().encode(notif)
        try await transport.send(data)

        return parseInitializeResult(result)
    }

    /// Ping the server.
    public func ping() async throws {
        _ = try await send(method: "ping", params: nil)
    }

    // MARK: Tools

    public func listTools() async throws -> [MCPTool] {
        let result = try await send(method: "tools/list", params: nil)
        guard case .object(let obj) = result,
              case .array(let toolsVal) = obj["tools"] else { return [] }
        return toolsVal.compactMap { parseTool($0) }
    }

    public func callTool(
        name: String,
        arguments: [String: JSONValue],
        meta: [String: JSONValue]? = nil
    ) async throws -> ToolCallResult {
        var paramsDict: [String: JSONValue] = [
            "name": .string(name),
            "arguments": .object(arguments)
        ]
        if let meta {
            paramsDict["_meta"] = .object(meta)
        }
        let result = try await send(method: "tools/call", params: .object(paramsDict))
        return parseToolCallResult(result)
    }

    // MARK: Resources

    public func listResources() async throws -> [MCPResource] {
        let result = try await send(method: "resources/list", params: nil)
        guard case .object(let obj) = result,
              case .array(let items) = obj["resources"] else { return [] }
        return items.compactMap { parseResource($0) }
    }

    public func readResource(uri: String) async throws -> ResourceContent {
        let params: JSONValue = .object(["uri": .string(uri)])
        let result = try await send(method: "resources/read", params: params)
        return parseResourceContent(uri: uri, result: result)
    }

    // MARK: Prompts

    public func listPrompts() async throws -> [MCPPrompt] {
        let result = try await send(method: "prompts/list", params: nil)
        guard case .object(let obj) = result,
              case .array(let items) = obj["prompts"] else { return [] }
        return items.compactMap { parsePrompt($0) }
    }

    public func getPrompt(name: String, arguments: [String: String]? = nil) async throws -> PromptContent {
        var paramsDict: [String: JSONValue] = ["name": .string(name)]
        if let args = arguments {
            paramsDict["arguments"] = .object(args.mapValues { .string($0) })
        }
        let result = try await send(method: "prompts/get", params: .object(paramsDict))
        return parsePromptContent(result)
    }

    // MARK: Close

    public func close() async {
        isRunning = false
        let err = MCPClientError.closed
        for (_, cont) in pendingRequests {
            cont.resume(throwing: err)
        }
        pendingRequests = [:]
        await transport.close()
    }

    // MARK: Internal: Send/Receive

    private func send(method: String, params: JSONValue?) async throws -> JSONValue {
        let id = JSONRPCId.number(nextId)
        nextId += 1

        let request = JSONRPCRequest(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(request)

        return try await withCheckedThrowingContinuation { cont in
            pendingRequests[id] = cont
            Task {
                do {
                    try await self.transport.send(data)
                } catch {
                    await self.failRequest(id: id, error: error)
                }
            }
            // Apply timeout
            let timeout = self.requestTimeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await self.timeoutRequest(id: id)
            }
        }
    }

    private func failRequest(id: JSONRPCId, error: Error) {
        if let cont = pendingRequests.removeValue(forKey: id) {
            cont.resume(throwing: error)
        }
    }

    private func timeoutRequest(id: JSONRPCId) {
        if let cont = pendingRequests.removeValue(forKey: id) {
            cont.resume(throwing: MCPClientError.timeout)
        }
    }

    private func startReceiveLoop() {
        Task {
            while self.isRunning {
                do {
                    let data = try await self.transport.receive()
                    await self.handleIncoming(data)
                } catch {
                    if self.isRunning {
                        self.isRunning = false
                        let err = MCPClientError.closed
                        for (_, cont) in self.pendingRequests {
                            cont.resume(throwing: err)
                        }
                        self.pendingRequests = [:]
                    }
                    break
                }
            }
        }
    }

    private func handleIncoming(_ data: Data) {
        // Try to parse as a response
        if let response = try? JSONDecoder().decode(JSONRPCResponse.self, from: data) {
            let id = response.id
            guard let cont = pendingRequests.removeValue(forKey: id) else { return }
            if let error = response.error {
                cont.resume(throwing: MCPClientError.serverError(error))
            } else {
                cont.resume(returning: response.result ?? .null)
            }
        }
        // Notifications are silently ignored for now
    }

    // MARK: Parsers

    private func parseInitializeResult(_ value: JSONValue) -> InitializeResult {
        guard case .object(let obj) = value else {
            return InitializeResult(
                protocolVersion: "2024-11-05",
                serverInfo: ServerInfo(name: "unknown", version: "0.0"),
                capabilities: ServerCapabilities()
            )
        }
        let proto: String
        if case .string(let v) = obj["protocolVersion"] { proto = v } else { proto = "2024-11-05" }

        let name: String
        let version: String
        if case .object(let info) = obj["serverInfo"] {
            name = (info["name"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }) ?? "unknown"
            version = (info["version"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }) ?? "0"
        } else {
            name = "unknown"; version = "0"
        }

        var caps = ServerCapabilities()
        if case .object(let capObj) = obj["capabilities"] {
            caps = ServerCapabilities(
                tools: capObj["tools"] != nil,
                resources: capObj["resources"] != nil,
                prompts: capObj["prompts"] != nil
            )
        }

        return InitializeResult(
            protocolVersion: proto,
            serverInfo: ServerInfo(name: name, version: version),
            capabilities: caps
        )
    }

    private func parseTool(_ value: JSONValue) -> MCPTool? {
        guard case .object(let obj) = value,
              case .string(let name) = obj["name"] else { return nil }
        let desc: String?
        if case .string(let d) = obj["description"] { desc = d } else { desc = nil }
        return MCPTool(name: name, description: desc, inputSchema: obj["inputSchema"])
    }

    private func parseToolCallResult(_ value: JSONValue) -> ToolCallResult {
        guard case .object(let obj) = value else {
            return ToolCallResult(content: [.text(String(describing: value))], isError: false)
        }
        let isError: Bool
        if case .bool(let b) = obj["isError"] { isError = b } else { isError = false }

        // 2.1.89 backport: preserve ALL content blocks, never truncate to first
        var blocks: [MCPContentBlock] = []
        if case .array(let items) = obj["content"] {
            for item in items {
                if let block = try? JSONDecoder().decode(MCPContentBlock.self, from: JSONEncoder().encode(item)) {
                    blocks.append(block)
                } else if case .object(let b) = item, case .string(let text) = b["text"] {
                    blocks.append(.text(text))
                }
            }
        }
        if blocks.isEmpty {
            blocks = [.text(String(describing: value))]
        }
        return ToolCallResult(content: blocks, isError: isError)
    }

    private func parseResource(_ value: JSONValue) -> MCPResource? {
        guard case .object(let obj) = value,
              case .string(let uri) = obj["uri"],
              case .string(let name) = obj["name"] else { return nil }
        let desc: String?
        if case .string(let d) = obj["description"] { desc = d } else { desc = nil }
        let mime: String?
        if case .string(let m) = obj["mimeType"] { mime = m } else { mime = nil }
        return MCPResource(uri: uri, name: name, description: desc, mimeType: mime)
    }

    private func parseResourceContent(uri: String, result: JSONValue) -> ResourceContent {
        guard case .object(let obj) = result,
              case .array(let contents) = obj["contents"],
              let first = contents.first,
              case .object(let c) = first else {
            return ResourceContent(uri: uri)
        }
        let mime: String?
        if case .string(let m) = c["mimeType"] { mime = m } else { mime = nil }
        let text: String?
        if case .string(let t) = c["text"] { text = t } else { text = nil }
        return ResourceContent(uri: uri, mimeType: mime, text: text)
    }

    private func parsePrompt(_ value: JSONValue) -> MCPPrompt? {
        guard case .object(let obj) = value,
              case .string(let name) = obj["name"] else { return nil }
        let desc: String?
        if case .string(let d) = obj["description"] { desc = d } else { desc = nil }
        return MCPPrompt(name: name, description: desc)
    }

    private func parsePromptContent(_ value: JSONValue) -> PromptContent {
        guard case .object(let obj) = value else {
            return PromptContent(messages: [])
        }
        let desc: String?
        if case .string(let d) = obj["description"] { desc = d } else { desc = nil }
        var messages: [PromptMessage] = []
        if case .array(let items) = obj["messages"] {
            for item in items {
                if case .object(let m) = item,
                   case .string(let role) = m["role"],
                   case .object(let content) = m["content"],
                   case .string(let text) = content["text"] {
                    messages.append(PromptMessage(role: role, content: .text(text)))
                }
            }
        }
        return PromptContent(description: desc, messages: messages)
    }
}
