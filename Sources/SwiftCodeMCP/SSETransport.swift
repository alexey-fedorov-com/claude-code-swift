/// Server-Sent Events (SSE) transport stub for MCP.
///
/// SSE transport connects to an HTTP endpoint and streams events.
/// Requests are sent as POST; responses come back as SSE events.
/// This is a stub — full implementation requires AsyncHTTPClient + SSE parsing.

import Foundation

// MARK: - SSETransport

/// Stub SSE transport for MCP. Streams events from an HTTP endpoint.
public actor SSETransport: Transport {

    private let sseURL: URL
    private let postURL: URL
    private var pendingData: [Data] = []
    private var continuation: CheckedContinuation<Data, Error>?
    private var isClosed = false

    public init(sseURL: URL, postURL: URL) {
        self.sseURL = sseURL
        self.postURL = postURL
    }

    public func start() async throws {
        // TODO: Open SSE stream to sseURL, parse event: / data: lines
    }

    public func send(_ message: Data) async throws {
        guard !isClosed else { throw TransportError.notConnected }
        // TODO: POST to postURL
        _ = message
        throw TransportError.invalidMessage("SSETransport.send not yet implemented")
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
