/// MCP server configuration, parsed from settings.json `mcpServers`.
///
/// Maps the TypeScript McpServerConfig type hierarchy:
/// - StdioServerDefinition: command + args + env
/// - SseServerDefinition: url
/// - HttpServerDefinition: url + headers

import Foundation

// MARK: - MCPServerTransportType

public enum MCPServerTransportType: String, Codable, Sendable {
    case stdio
    case sse
    case http
}

// MARK: - MCPServerConfig

/// A single configured MCP server, as stored in settings.json `mcpServers`.
public struct MCPServerConfig: Codable, Sendable {
    /// The transport type. Defaults to stdio if command is set.
    public let type: MCPServerTransportType

    // stdio fields
    public let command: String?
    public let args: [String]?
    public let env: [String: String]?

    // sse/http fields
    public let url: String?
    public let headers: [String: String]?

    // Common
    public let timeout: TimeInterval?

    public init(
        type: MCPServerTransportType = .stdio,
        command: String? = nil,
        args: [String]? = nil,
        env: [String: String]? = nil,
        url: String? = nil,
        headers: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.type = type
        self.command = command
        self.args = args
        self.env = env
        self.url = url
        self.headers = headers
        self.timeout = timeout
    }

    private enum CodingKeys: String, CodingKey {
        case type, command, args, env, url, headers, timeout
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Infer type from fields if not explicit
        if let raw = try c.decodeIfPresent(String.self, forKey: .type) {
            self.type = MCPServerTransportType(rawValue: raw) ?? .stdio
        } else if (try c.decodeIfPresent(String.self, forKey: .url)) != nil {
            self.type = .sse
        } else {
            self.type = .stdio
        }
        self.command = try c.decodeIfPresent(String.self, forKey: .command)
        self.args = try c.decodeIfPresent([String].self, forKey: .args)
        self.env = try c.decodeIfPresent([String: String].self, forKey: .env)
        self.url = try c.decodeIfPresent(String.self, forKey: .url)
        self.headers = try c.decodeIfPresent([String: String].self, forKey: .headers)
        self.timeout = try c.decodeIfPresent(TimeInterval.self, forKey: .timeout)
    }
}

// MARK: - MCPSettings

/// The `mcpServers` key from settings.json.
public struct MCPSettings: Codable, Sendable {
    /// Map from server name to its config.
    public let servers: [String: MCPServerConfig]

    public init(servers: [String: MCPServerConfig]) {
        self.servers = servers
    }

    private enum CodingKeys: String, CodingKey {
        case servers = "mcpServers"
    }
}
