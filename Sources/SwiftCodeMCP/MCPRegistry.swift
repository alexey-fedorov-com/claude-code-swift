/// Registry of all configured MCP servers.
///
/// Loaded from settings.json `mcpServers`, holds MCPServer instances,
/// and provides aggregated tool/resource/prompt discovery.

import Foundation
import SwiftCodeCore

// MARK: - MCPRegistry

/// Holds all configured MCP servers and aggregates their capabilities.
public actor MCPRegistry {

    private var servers: [String: MCPServer] = [:]

    public init() {}

    // MARK: Server Management

    /// Load servers from MCPSettings.
    public func loadServers(from settings: MCPSettings) {
        for (name, config) in settings.servers {
            servers[name] = MCPServer(name: name, config: config)
        }
    }

    /// Add a server manually.
    public func addServer(name: String, config: MCPServerConfig) {
        servers[name] = MCPServer(name: name, config: config)
    }

    /// Remove a server by name.
    public func removeServer(name: String) {
        servers.removeValue(forKey: name)
    }

    /// Get all server names.
    public var serverNames: [String] { Array(servers.keys).sorted() }

    /// Get a specific server.
    public func server(named name: String) -> MCPServer? {
        servers[name]
    }

    // MARK: Connection Management

    /// Connect all servers.
    public func connectAll() async {
        await withTaskGroup(of: Void.self) { group in
            for server in servers.values {
                group.addTask {
                    try? await server.connect()
                }
            }
        }
    }

    /// Disconnect all servers.
    public func disconnectAll() async {
        await withTaskGroup(of: Void.self) { group in
            for server in servers.values {
                group.addTask {
                    await server.disconnect()
                }
            }
        }
    }

    // MARK: Aggregated Discovery

    /// List all tools across all connected servers.
    public func allTools() async -> [(serverName: String, tool: MCPTool)] {
        var result: [(String, MCPTool)] = []
        for (name, server) in servers {
            if let tools = try? await server.listTools() {
                result.append(contentsOf: tools.map { (name, $0) })
            }
        }
        return result
    }

    /// List all resources across all connected servers.
    public func allResources() async -> [(serverName: String, resource: MCPResource)] {
        var result: [(String, MCPResource)] = []
        for (name, server) in servers {
            if let resources = try? await server.listResources() {
                result.append(contentsOf: resources.map { (name, $0) })
            }
        }
        return result
    }

    /// List all prompts across all connected servers.
    public func allPrompts() async -> [(serverName: String, prompt: MCPPrompt)] {
        var result: [(String, MCPPrompt)] = []
        for (name, server) in servers {
            if let prompts = try? await server.listPrompts() {
                result.append(contentsOf: prompts.map { (name, $0) })
            }
        }
        return result
    }
}
