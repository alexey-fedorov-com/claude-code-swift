import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1
import SwiftCodeCore

// MARK: - Beta Headers
// Matches constants/betas.ts

private enum BetaHeaders {
    static let claudeCode           = "claude-code-20250219"
    static let interleavedThinking  = "interleaved-thinking-2025-05-14"
    static let context1M            = "context-1m-2025-08-07"
    static let contextManagement    = "context-management-2025-06-27"
    static let structuredOutputs    = "structured-outputs-2025-12-15"
    static let webSearch            = "web-search-2025-03-05"
    static let toolSearch1P         = "advanced-tool-use-2025-11-20"
    static let toolSearch3P         = "tool-search-tool-2025-10-19"
    static let effort               = "effort-2025-11-24"
    static let taskBudgets          = "task-budgets-2026-03-13"
    static let promptCachingScope   = "prompt-caching-scope-2026-01-05"
    static let fastMode             = "fast-mode-2026-02-01"
    static let redactThinking       = "redact-thinking-2026-02-12"
    static let tokenEfficientTools  = "token-efficient-tools-2026-03-28"
    static let advisor              = "advisor-tool-2026-03-01"
    static let oauth                = "oauth-2025-04-20"
}

// MARK: - Request Types

public struct ThinkingConfig: Sendable, Codable {
    public var type: String     // "enabled" | "disabled"
    public var budgetTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case type
        case budgetTokens = "budget_tokens"
    }

    public init(type: String = "enabled", budgetTokens: Int? = nil) {
        self.type = type
        self.budgetTokens = budgetTokens
    }
}

public struct CacheControl: Sendable, Codable {
    public var type: String  // "ephemeral"

    public init(type: String = "ephemeral") {
        self.type = type
    }

    public static let ephemeral = CacheControl(type: "ephemeral")
}

public struct ToolDefinition: Sendable, Codable {
    public var name: String
    public var description: String?
    public var inputSchema: JSONValue

    private enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }

    public init(name: String, description: String? = nil, inputSchema: JSONValue = .object([:]))  {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

public struct SystemBlock: Sendable, Codable {
    public var type: String              // "text"
    public var text: String
    public var cacheControl: CacheControl?

    private enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }

    public init(text: String, cacheControl: CacheControl? = nil) {
        self.type = "text"
        self.text = text
        self.cacheControl = cacheControl
    }
}

/// A single message in the conversation history sent to the API.
/// Kept separate from SwiftCodeCore.Message (which is the session transcript type).
public struct APIMessage: Sendable, Codable {
    public var role: String      // "user" | "assistant"
    public var content: JSONValue

    public init(role: String, content: JSONValue) {
        self.role = role
        self.content = content
    }
}

public struct MessagesRequest: Sendable, Codable {
    // Required
    public var model: String
    public var maxTokens: Int
    public var messages: [APIMessage]

    // Optional
    public var system: [SystemBlock]?
    public var tools: [ToolDefinition]?
    public var temperature: Double?
    public var topP: Double?
    public var topK: Int?
    public var stream: Bool?
    public var stopSequences: [String]?
    public var thinking: ThinkingConfig?
    public var metadata: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case tools
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stream
        case stopSequences = "stop_sequences"
        case thinking
        case metadata
    }

    public init(
        model: String,
        maxTokens: Int,
        messages: [APIMessage],
        system: [SystemBlock]? = nil,
        tools: [ToolDefinition]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stream: Bool? = nil,
        stopSequences: [String]? = nil,
        thinking: ThinkingConfig? = nil,
        metadata: [String: String]? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.messages = messages
        self.system = system
        self.tools = tools
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stream = stream
        self.stopSequences = stopSequences
        self.thinking = thinking
        self.metadata = metadata
    }
}

// MARK: - Response Types

public struct ContentBlock: Sendable, Codable {
    public var type: String
    public var text: String?
    public var id: String?
    public var name: String?
    public var input: JSONValue?
    public var thinking: String?
    public var signature: String?

    public init(
        type: String,
        text: String? = nil,
        id: String? = nil,
        name: String? = nil,
        input: JSONValue? = nil,
        thinking: String? = nil,
        signature: String? = nil
    ) {
        self.type = type
        self.text = text
        self.id = id
        self.name = name
        self.input = input
        self.thinking = thinking
        self.signature = signature
    }
}

public struct MessagesResponse: Sendable, Codable {
    public var id: String
    public var type: String
    public var role: String
    public var content: [ContentBlock]
    public var model: String
    public var stopReason: String?
    public var stopSequence: String?
    public var usage: UsageResponse

    private enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, usage
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }

    public init(
        id: String,
        type: String = "message",
        role: String = "assistant",
        content: [ContentBlock],
        model: String,
        stopReason: String? = nil,
        stopSequence: String? = nil,
        usage: UsageResponse
    ) {
        self.id = id
        self.type = type
        self.role = role
        self.content = content
        self.model = model
        self.stopReason = stopReason
        self.stopSequence = stopSequence
        self.usage = usage
    }
}

public struct UsageResponse: Sendable, Codable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadInputTokens: Int?
    public var cacheCreationInputTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
    }

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheReadInputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
    }
}

// MARK: - AnthropicClient

/// Async Anthropic Messages API client backed by AsyncHTTPClient.
/// Supports non-streaming and streaming (SSE) modes.
///
/// Thread-safe actor. Shares one `HTTPClient` across calls.
/// The caller is responsible for shutting down the HTTP client on exit.
public actor AnthropicClient {

    // MARK: Config

    private let apiKey: String
    private let baseURL: URL
    private let httpClient: HTTPClient
    private let ownsHTTPClient: Bool
    private let retryPolicy: RetryPolicy
    private let anthropicVersion: String = "2023-06-01"
    private let provider: APIProvider

    // MARK: Init

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        httpClient: HTTPClient? = nil,
        retryPolicy: RetryPolicy = .default,
        provider: APIProvider = .anthropic
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.retryPolicy = retryPolicy
        self.provider = provider

        if let client = httpClient {
            self.httpClient = client
            self.ownsHTTPClient = false
        } else {
            var config = HTTPClient.Configuration()
            config.timeout = HTTPClient.Configuration.Timeout(
                connect: .seconds(30),
                read: .seconds(600)
            )
            self.httpClient = HTTPClient(configuration: config)
            self.ownsHTTPClient = true
        }
    }

    deinit {
        if ownsHTTPClient {
            // Best-effort shutdown. Full lifecycle should be managed by the caller.
            try? httpClient.syncShutdown()
        }
    }

    // MARK: - Non-Streaming

    /// Send a messages request and return the complete response.
    public func messages(_ request: MessagesRequest) async throws -> MessagesResponse {
        var req = request
        req.stream = false

        let httpRequest = try buildHTTPRequest(request: req, streaming: false)

        return try await RetryExecutor.execute(policy: retryPolicy) {
            let response = try await self.httpClient.execute(httpRequest, timeout: .seconds(600))
            return try await self.decodeResponse(response)
        }
    }

    // MARK: - Streaming

    /// Stream a messages request, yielding `StreamEvent` values as they arrive.
    public nonisolated func messagesStream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var req = request
                    req.stream = true
                    let httpRequest = try self.buildHTTPRequest(request: req, streaming: true)

                    let response = try await self.httpClient.execute(httpRequest, timeout: .seconds(600))

                    guard (200..<300).contains(response.status.code) else {
                        let body = try await response.body.collect(upTo: 64 * 1024)
                        let msg = String(buffer: body)
                        throw APIError.httpError(statusCode: Int(response.status.code), message: msg)
                    }

                    var parser = SSEStreamingParser()
                    for try await chunk in response.body {
                        var bytes = [UInt8](repeating: 0, count: chunk.readableBytes)
                        var mutableChunk = chunk
                        mutableChunk.readBytes(length: chunk.readableBytes).flatMap { b in bytes = b }
                        let events = try parser.feed(bytes)
                        for event in events {
                            continuation.yield(event)
                            if case .messageStop = event {
                                continuation.finish()
                                return
                            }
                            if case .error(let err) = event {
                                continuation.finish(throwing: APIError.unknown(message: err.message))
                                return
                            }
                        }
                    }

                    // Flush any remaining buffer
                    let finalEvents = try parser.finish()
                    for event in finalEvents {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Request Construction

    nonisolated func buildHTTPRequest(
        request: MessagesRequest,
        streaming: Bool
    ) throws -> HTTPClientRequest {
        let url = baseURL.appendingPathComponent("/v1/messages")
        var httpRequest = HTTPClientRequest(url: url.absoluteString)
        httpRequest.method = .POST

        // Headers
        httpRequest.headers.add(name: "Content-Type", value: "application/json")
        httpRequest.headers.add(name: "x-api-key", value: apiKey)
        httpRequest.headers.add(name: "anthropic-version", value: anthropicVersion)

        // Compose beta headers
        let betas = composeBetaHeaders(request: request)
        if !betas.isEmpty {
            httpRequest.headers.add(name: "anthropic-beta", value: betas.joined(separator: ","))
        }

        // Encode body
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let bodyData = try encoder.encode(request)
        httpRequest.body = .bytes(ByteBuffer(data: bodyData))

        return httpRequest
    }

    nonisolated func composeBetaHeaders(request: MessagesRequest) -> [String] {
        var betas: [String] = [BetaHeaders.claudeCode]

        // Prompt caching — always enabled for first-party
        if provider == .anthropic {
            betas.append(BetaHeaders.promptCachingScope)
        }

        // Thinking / extended thinking
        if let thinking = request.thinking, thinking.type == "enabled" {
            betas.append(BetaHeaders.interleavedThinking)
        }

        // Tool definitions signal tool search capability
        if let tools = request.tools, !tools.isEmpty {
            if provider == .anthropic || provider == .foundry {
                betas.append(BetaHeaders.toolSearch1P)
            } else {
                betas.append(BetaHeaders.toolSearch3P)
            }
            betas.append(BetaHeaders.tokenEfficientTools)
        }

        return betas
    }

    // MARK: - Response Decoding

    private func decodeResponse(_ response: HTTPClientResponse) async throws -> MessagesResponse {
        let statusCode = Int(response.status.code)
        guard (200..<300).contains(statusCode) else {
            let body = try await response.body.collect(upTo: 64 * 1024)
            let msg = String(buffer: body)
            throw mapHTTPError(statusCode: statusCode, body: msg)
        }

        let bodyBuf = try await response.body.collect(upTo: 100 * 1024 * 1024) // 100MB
        let bodyData = Data(buffer: bodyBuf)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(MessagesResponse.self, from: bodyData)
        } catch {
            throw APIError.decodingError(underlying: error)
        }
    }

    private func mapHTTPError(statusCode: Int, body: String) -> APIError {
        switch statusCode {
        case 401:
            return .authError(message: "Invalid API key")
        case 429:
            return .rateLimited(retryAfter: nil)
        case 529:
            return .overloaded
        default:
            return .httpError(statusCode: statusCode, message: body.isEmpty ? nil : body)
        }
    }
}

// MARK: - AnthropicClient + Factory

extension AnthropicClient {

    /// Convenience factory that reads credentials from the environment.
    public static func fromEnvironment(
        env: [String: String] = ProcessInfo.processInfo.environment,
        retryPolicy: RetryPolicy = .default
    ) async throws -> AnthropicClient {
        let provider = ProviderDetector.detect(env: env)
        let baseURL = ProviderDetector.baseURL(env: env)

        let authProvider = CompositeAuthProvider.makeDefault(env: env)
        let creds = try await authProvider.credentials()

        // Prefer OAuth bearer over raw API key
        let apiKey: String
        if let token = creds.oauthToken?.accessToken {
            apiKey = token
        } else if let key = creds.apiKey {
            apiKey = key
        } else {
            throw AuthError.noCredentials
        }

        return AnthropicClient(
            apiKey: apiKey,
            baseURL: baseURL,
            retryPolicy: retryPolicy,
            provider: provider
        )
    }
}

// MARK: - Helpers

private extension Data {
    init(buffer: ByteBuffer) {
        var mutableBuffer = buffer
        let bytes = mutableBuffer.readBytes(length: mutableBuffer.readableBytes) ?? []
        self = Data(bytes)
    }
}

private extension Optional where Wrapped == ByteBuffer {
    func map<T>(_ transform: (ByteBuffer) -> T) -> T? {
        guard let self = self else { return nil }
        return transform(self)
    }
}

private extension String {
    init(buffer: ByteBuffer) {
        var mutableBuffer = buffer
        let bytes = mutableBuffer.readBytes(length: mutableBuffer.readableBytes) ?? []
        self = String(bytes: bytes, encoding: .utf8) ?? ""
    }
}
