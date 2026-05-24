import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

/// Validates an Anthropic API key by issuing a cheap authenticated request.
///
/// We hit `GET /v1/models` because it's the lowest-cost authenticated endpoint
/// — a 200 means the key works, a 401 means it's bad, any other code is a
/// transient/server problem.
public struct ApiKeyValidator: Sendable {

    public enum ValidationResult: Sendable, Equatable {
        case valid
        case invalid(reason: String)
        case transientError(message: String)
    }

    private let baseURL: URL
    private let httpClient: HTTPClient
    private let ownsClient: Bool

    public init(
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        httpClient: HTTPClient? = nil
    ) {
        self.baseURL = baseURL
        if let client = httpClient {
            self.httpClient = client
            self.ownsClient = false
        } else {
            var config = HTTPClient.Configuration()
            config.timeout = HTTPClient.Configuration.Timeout(
                connect: .seconds(10),
                read: .seconds(30)
            )
            self.httpClient = HTTPClient(configuration: config)
            self.ownsClient = true
        }
    }

    public func validate(apiKey: String) async -> ValidationResult {
        let url = baseURL.appendingPathComponent("/v1/models")
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .GET
        request.headers.add(name: "x-api-key", value: apiKey)
        request.headers.add(name: "anthropic-version", value: "2023-06-01")

        do {
            let response = try await httpClient.execute(request, timeout: .seconds(30))
            let status = Int(response.status.code)
            switch status {
            case 200..<300:
                return .valid
            case 401, 403:
                return .invalid(reason: "Key was rejected by the server (HTTP \(status))")
            default:
                let body = try? await response.body.collect(upTo: 4 * 1024)
                let msg = body.map { String(buffer: $0) } ?? ""
                return .transientError(message: "HTTP \(status): \(msg)")
            }
        } catch {
            return .transientError(message: "\(error)")
        }
    }

    /// Shut down the owned HTTPClient if one was created internally.
    public func shutdown() async {
        guard ownsClient else { return }
        try? await httpClient.shutdown()
    }
}

private extension String {
    init(buffer: ByteBuffer) {
        var b = buffer
        let bytes = b.readBytes(length: b.readableBytes) ?? []
        self = String(bytes: bytes, encoding: .utf8) ?? ""
    }
}
