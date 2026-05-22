import XCTest
@testable import SwiftCodeAPI

final class RequestConstructionTests: XCTestCase {

    // MARK: - MessagesRequest Encoding

    func testDefaultModelIncluded() throws {
        let request = MessagesRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            messages: [APIMessage(role: "user", content: .string("hi"))]
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["model"] as? String, "claude-sonnet-4-6")
        XCTAssertEqual(json["max_tokens"] as? Int, 1024)
    }

    func testSystemPromptPlacedCorrectly() throws {
        let request = MessagesRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            messages: [APIMessage(role: "user", content: .string("hello"))],
            system: [SystemBlock(text: "You are helpful.")]
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let system = json["system"] as? [[String: Any]]
        XCTAssertNotNil(system)
        XCTAssertEqual(system?.count, 1)
        XCTAssertEqual(system?.first?["type"] as? String, "text")
        XCTAssertEqual(system?.first?["text"] as? String, "You are helpful.")
    }

    func testToolsSerializedCorrectly() throws {
        let tool = ToolDefinition(
            name: "bash",
            description: "Run bash commands",
            inputSchema: .object(["command": .object(["type": .string("string")])])
        )
        let request = MessagesRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            messages: [],
            tools: [tool]
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let tools = json["tools"] as? [[String: Any]]
        XCTAssertNotNil(tools)
        XCTAssertEqual(tools?.count, 1)
        XCTAssertEqual(tools?.first?["name"] as? String, "bash")
        XCTAssertEqual(tools?.first?["description"] as? String, "Run bash commands")
        XCTAssertNotNil(tools?.first?["input_schema"])
    }

    func testStreamFieldIncludedWhenTrue() throws {
        let request = MessagesRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            messages: [],
            stream: true
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["stream"] as? Bool, true)
    }

    func testStreamFieldAbsentWhenNil() throws {
        let request = MessagesRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            messages: []
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNil(json["stream"])
    }

    func testThinkingConfigIncluded() throws {
        let request = MessagesRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 16000,
            messages: [],
            thinking: ThinkingConfig(type: "enabled", budgetTokens: 8000)
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let thinking = json["thinking"] as? [String: Any]
        XCTAssertNotNil(thinking)
        XCTAssertEqual(thinking?["type"] as? String, "enabled")
        XCTAssertEqual(thinking?["budget_tokens"] as? Int, 8000)
    }

    func testCacheControlInSystemBlock() throws {
        let system = SystemBlock(text: "System prompt.", cacheControl: .ephemeral)
        let request = MessagesRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            messages: [],
            system: [system]
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let systemArr = json["system"] as? [[String: Any]]
        let cacheControl = systemArr?.first?["cache_control"] as? [String: Any]
        XCTAssertNotNil(cacheControl)
        XCTAssertEqual(cacheControl?["type"] as? String, "ephemeral")
    }

    // MARK: - Header Construction

    func testHeadersIncludeAPIKey() throws {
        let client = AnthropicClient(apiKey: "sk-test-key-1234")
        let request = MessagesRequest(model: "claude-sonnet-4-6", maxTokens: 1024, messages: [])
        let httpRequest = try client.buildHTTPRequest(request: request, streaming: false)

        XCTAssertEqual(httpRequest.headers["x-api-key"].first, "sk-test-key-1234")
    }

    func testHeadersIncludeAnthropicVersion() throws {
        let client = AnthropicClient(apiKey: "sk-test")
        let request = MessagesRequest(model: "claude-sonnet-4-6", maxTokens: 1024, messages: [])
        let httpRequest = try client.buildHTTPRequest(request: request, streaming: false)

        XCTAssertEqual(httpRequest.headers["anthropic-version"].first, "2023-06-01")
    }

    func testHeadersIncludeAnthropicBeta() throws {
        let client = AnthropicClient(apiKey: "sk-test")
        let request = MessagesRequest(model: "claude-sonnet-4-6", maxTokens: 1024, messages: [])
        let httpRequest = try client.buildHTTPRequest(request: request, streaming: false)

        let betaHeader = httpRequest.headers["anthropic-beta"].first
        XCTAssertNotNil(betaHeader, "anthropic-beta header must be present")
        XCTAssertTrue(betaHeader?.contains("claude-code-20250219") == true,
                      "anthropic-beta must include claude-code header")
    }

    func testToolSearchBetaHeaderAddedWithTools() throws {
        let client = AnthropicClient(apiKey: "sk-test", provider: .anthropic)
        let tool = ToolDefinition(name: "read_file", inputSchema: .object([:]))
        let request = MessagesRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 1024,
            messages: [],
            tools: [tool]
        )
        let httpRequest = try client.buildHTTPRequest(request: request, streaming: false)
        let betaHeader = httpRequest.headers["anthropic-beta"].first ?? ""
        XCTAssertTrue(betaHeader.contains("advanced-tool-use-2025-11-20"),
                      "Tool search beta header must be present when tools defined (got: \(betaHeader))")
    }

    func testThinkingBetaHeaderAddedWhenThinkingEnabled() throws {
        let client = AnthropicClient(apiKey: "sk-test")
        let request = MessagesRequest(
            model: "claude-sonnet-4-6",
            maxTokens: 16000,
            messages: [],
            thinking: ThinkingConfig(type: "enabled")
        )
        let httpRequest = try client.buildHTTPRequest(request: request, streaming: false)
        let betaHeader = httpRequest.headers["anthropic-beta"].first ?? ""
        XCTAssertTrue(betaHeader.contains("interleaved-thinking-2025-05-14"),
                      "Thinking beta header must be present (got: \(betaHeader))")
    }

    func testContentTypeIsJSON() throws {
        let client = AnthropicClient(apiKey: "sk-test")
        let request = MessagesRequest(model: "claude-sonnet-4-6", maxTokens: 1024, messages: [])
        let httpRequest = try client.buildHTTPRequest(request: request, streaming: false)
        XCTAssertEqual(httpRequest.headers["Content-Type"].first, "application/json")
    }

    func testRequestBodyEncodedAsJSON() throws {
        let client = AnthropicClient(apiKey: "sk-test")
        let msg = APIMessage(role: "user", content: .string("test"))
        let request = MessagesRequest(model: "claude-opus-4-6", maxTokens: 512, messages: [msg])
        let httpRequest = try client.buildHTTPRequest(request: request, streaming: false)
        XCTAssertNotNil(httpRequest.body)
    }
}
