/// Direct-connect paths: server, open, ssh.
///
/// These are stubs — they require server infrastructure that is not yet
/// available in this Swift rewrite. The types and URL/arg parsing are complete.

import Foundation

// MARK: - ConnectMode

public enum ConnectMode: Sendable {
    /// Connect to a local or remote server by URL.
    case server(URL)
    /// Open a named existing session.
    case open(String)
    /// Connect via SSH tunnel.
    case ssh(host: String, port: Int?, user: String?)
}

// MARK: - DirectConnectConfig

public struct DirectConnectConfig: Sendable {
    public let mode: ConnectMode
    /// Optional session ID to resume.
    public let sessionId: String?
    /// Optional API key override.
    public let apiKey: String?

    public init(mode: ConnectMode, sessionId: String? = nil, apiKey: String? = nil) {
        self.mode = mode
        self.sessionId = sessionId
        self.apiKey = apiKey
    }

    // MARK: Parsing

    /// Parse a server URL string into a ConnectConfig.
    public static func parseServer(_ urlString: String) throws -> DirectConnectConfig {
        guard let url = URL(string: urlString), url.scheme != nil, !url.scheme!.isEmpty else {
            throw DirectConnectError.invalidURL(urlString)
        }
        return DirectConnectConfig(mode: .server(url))
    }

    /// Parse an SSH connection string (user@host:port).
    public static func parseSSH(_ connection: String) -> DirectConnectConfig {
        var remainder = connection
        var user: String? = nil

        if let atRange = remainder.range(of: "@") {
            user = String(remainder[..<atRange.lowerBound])
            remainder = String(remainder[atRange.upperBound...])
        }

        var host = remainder
        var port: Int? = nil

        if let colonRange = remainder.lastIndex(of: ":") {
            let portStr = String(remainder[remainder.index(after: colonRange)...])
            if let p = Int(portStr) {
                port = p
                host = String(remainder[..<colonRange])
            }
        }

        return DirectConnectConfig(mode: .ssh(host: host, port: port, user: user))
    }

    /// Parse an `--open <sessionId>` connection.
    public static func parseOpen(_ sessionId: String) -> DirectConnectConfig {
        DirectConnectConfig(mode: .open(sessionId))
    }
}

// MARK: - DirectConnectError

public enum DirectConnectError: Error, Sendable {
    case invalidURL(String)
    case notImplemented(String)
    case connectionFailed(String)
}

// MARK: - DirectConnect (stub)

/// Manages direct connections to Claude Code server instances.
/// Currently stub — actual connection requires server infrastructure.
public actor DirectConnect {

    private let config: DirectConnectConfig
    private var isConnected = false

    public init(config: DirectConnectConfig) {
        self.config = config
    }

    /// Attempt to connect. Currently always throws `.notImplemented`.
    public func connect() async throws {
        switch config.mode {
        case .server(let url):
            throw DirectConnectError.notImplemented(
                "Server connect to \(url) not yet implemented"
            )
        case .open(let sessionId):
            throw DirectConnectError.notImplemented(
                "Open session \(sessionId) not yet implemented"
            )
        case .ssh(let host, let port, let user):
            let addr = user.map { "\($0)@\(host)" } ?? host
            let portStr = port.map { ":\($0)" } ?? ""
            throw DirectConnectError.notImplemented(
                "SSH connect to \(addr)\(portStr) not yet implemented"
            )
        }
    }

    public func disconnect() async {
        isConnected = false
    }

    public var connectMode: ConnectMode { config.mode }
}
