/// An installed MCP server with lifecycle management.
///
/// Wraps MCPConfig + MCPClient and handles start/stop/restart.

import Foundation

// MARK: - MCPServerState

public enum MCPServerState: Sendable {
    case disconnected
    case connecting
    case connected(InitializeResult)
    case failed(Error)
}

// MARK: - MCPServer

/// Manages the lifecycle of a single configured MCP server.
public actor MCPServer {

    public let name: String
    public let config: MCPServerConfig

    private var client: MCPClient?
    private(set) public var state: MCPServerState = .disconnected

    public init(name: String, config: MCPServerConfig) {
        self.name = name
        self.config = config
    }

    // MARK: Lifecycle

    public func connect() async throws {
        state = .connecting
        do {
            let transport = try makeTransport()
            let client = MCPClient(transport: transport)
            try await client.start()
            let result = try await client.initialize()
            self.client = client
            state = .connected(result)
        } catch {
            state = .failed(error)
            throw error
        }
    }

    public func disconnect() async {
        await client?.close()
        client = nil
        state = .disconnected
    }

    public func restart() async throws {
        await disconnect()
        try await connect()
    }

    // MARK: Passthrough

    public func listTools() async throws -> [MCPTool] {
        try await requireClient().listTools()
    }

    public func callTool(name: String, arguments: [String: JSONValue]) async throws -> ToolCallResult {
        try await requireClient().callTool(name: name, arguments: arguments)
    }

    public func listResources() async throws -> [MCPResource] {
        try await requireClient().listResources()
    }

    public func readResource(uri: String) async throws -> ResourceContent {
        try await requireClient().readResource(uri: uri)
    }

    public func listPrompts() async throws -> [MCPPrompt] {
        try await requireClient().listPrompts()
    }

    public func getPrompt(name: String, arguments: [String: String]? = nil) async throws -> PromptContent {
        try await requireClient().getPrompt(name: name, arguments: arguments)
    }

    public func ping() async throws {
        try await requireClient().ping()
    }

    // MARK: Helpers

    private func requireClient() throws -> MCPClient {
        guard let client else { throw MCPClientError.notInitialized }
        return client
    }

    private func makeTransport() throws -> any Transport {
        switch config.type {
        case .stdio:
            guard let command = config.command else {
                throw TransportError.invalidMessage("stdio server requires 'command'")
            }
            return StdioTransport(
                command: command,
                arguments: config.args ?? [],
                env: config.env
            )
        case .sse:
            guard let urlStr = config.url, let url = URL(string: urlStr) else {
                throw TransportError.invalidMessage("SSE server requires valid 'url'")
            }
            let postURL = url.appendingPathComponent("message")
            return SSETransport(sseURL: url, postURL: postURL)
        case .http:
            guard let urlStr = config.url, let url = URL(string: urlStr) else {
                throw TransportError.invalidMessage("HTTP server requires valid 'url'")
            }
            return HTTPTransport(baseURL: url)
        }
    }
}

// MARK: - JSONValue import

import SwiftCodeCore
