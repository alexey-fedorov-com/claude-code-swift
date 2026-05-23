/// HTTP transport stub for MCP.
///
/// The HTTP transport POSTs JSON-RPC requests to an endpoint and reads responses.
/// This is a stub — full implementation requires AsyncHTTPClient integration.

import Foundation

// MARK: - HTTPTransport

/// Stub HTTP transport for MCP. Communicates with an HTTP MCP server endpoint.
public actor HTTPTransport: Transport {

    private let baseURL: URL
    private var pendingData: [Data] = []
    private var continuation: CheckedContinuation<Data, Error>?
    private var isClosed = false

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func start() async throws {
        // TODO: Verify server is reachable, optionally fetch /sse endpoint
    }

    public func send(_ message: Data) async throws {
        guard !isClosed else { throw TransportError.notConnected }
        // TODO: POST message to baseURL, decode response, call deliverData
        _ = message
        throw TransportError.invalidMessage("HTTPTransport.send not yet implemented")
    }

    public func receive() async throws -> Data {
        if !pendingData.isEmpty {
            return pendingData.removeFirst()
        }
        return try await withCheckedThrowingContinuation { cont in
            if isClosed {
                cont.resume(throwing: TransportError.connectionClosed)
                return
            }
            self.continuation = cont
        }
    }

    public func close() async {
        isClosed = true
        continuation?.resume(throwing: TransportError.connectionClosed)
        continuation = nil
    }
}
