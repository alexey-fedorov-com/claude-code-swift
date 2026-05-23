/// SDK WebSocket URL parsing and connection skeleton.
///
/// When `--sdk-url` is specified, Claude Code connects to a remote agent
/// via WebSocket. This provides URL parsing and the basic connection type.
/// Full implementation requires NIO WebSocket or URLSessionWebSocketTask.

import Foundation

// MARK: - SDKWebSocketConfig

public struct SDKWebSocketConfig: Sendable {
    public let url: URL
    /// Optional bearer token for authentication.
    public let bearerToken: String?
    /// Optional session ID to resume.
    public let sessionId: String?

    public init(url: URL, bearerToken: String? = nil, sessionId: String? = nil) {
        self.url = url
        self.bearerToken = bearerToken
        self.sessionId = sessionId
    }

    // MARK: Parsing

    public static func parse(_ urlString: String) throws -> SDKWebSocketConfig {
        guard let url = URL(string: urlString), let scheme = url.scheme, !scheme.isEmpty else {
            throw SDKWebSocketError.invalidURL(urlString)
        }
        guard scheme == "ws" || scheme == "wss" else {
            throw SDKWebSocketError.invalidScheme(scheme)
        }
        return SDKWebSocketConfig(url: url)
    }

    public static func parse(_ urlString: String, bearerToken: String?, sessionId: String?) throws -> SDKWebSocketConfig {
        let base = try parse(urlString)
        return SDKWebSocketConfig(url: base.url, bearerToken: bearerToken, sessionId: sessionId)
    }
}

// MARK: - SDKWebSocketError

public enum SDKWebSocketError: Error, Sendable {
    case invalidURL(String)
    case invalidScheme(String)
    case notConnected
    case notImplemented
    case connectionFailed(String)
}

// MARK: - SDKWebSocket (skeleton)

/// Skeleton WebSocket client for `--sdk-url`. Not yet fully implemented.
public actor SDKWebSocket {

    public let config: SDKWebSocketConfig
    private var isConnected = false

    public init(config: SDKWebSocketConfig) {
        self.config = config
    }

    /// Connect to the WebSocket endpoint. Currently a stub.
    public func connect() async throws {
        throw SDKWebSocketError.notImplemented
    }

    /// Send a message. Currently a stub.
    public func send(_ data: Data) async throws {
        guard isConnected else { throw SDKWebSocketError.notConnected }
        throw SDKWebSocketError.notImplemented
    }

    /// Receive the next message. Currently a stub.
    public func receive() async throws -> Data {
        guard isConnected else { throw SDKWebSocketError.notConnected }
        throw SDKWebSocketError.notImplemented
    }

    public func disconnect() async {
        isConnected = false
    }
}
