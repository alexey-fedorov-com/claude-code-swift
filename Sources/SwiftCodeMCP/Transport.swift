/// Transport protocol for MCP communication.
///
/// Implementations send and receive raw Data (newline-delimited JSON for stdio,
/// HTTP bodies for HTTP transports, SSE chunks for SSE).

import Foundation

// MARK: - Transport

/// A bidirectional message transport.
public protocol Transport: Actor {
    /// Start the transport (connect, spawn process, etc.).
    func start() async throws

    /// Send a raw message.
    func send(_ message: Data) async throws

    /// Receive the next raw message. Blocks until one is available.
    func receive() async throws -> Data

    /// Shut down the transport cleanly.
    func close() async
}

// MARK: - TransportError

public enum TransportError: Error, Sendable {
    case notConnected
    case connectionClosed
    case timeout
    case processExited(Int32)
    case encodingFailed
    case invalidMessage(String)
}
