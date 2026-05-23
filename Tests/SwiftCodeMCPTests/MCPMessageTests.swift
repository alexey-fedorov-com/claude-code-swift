import XCTest
@testable import SwiftCodeMCP
import SwiftCodeCore

final class MCPMessageTests: XCTestCase {

    // MARK: - JSONRPCId

    func testIdNumber() throws {
        let id = JSONRPCId.number(42)
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(JSONRPCId.self, from: data)
        XCTAssertEqual(id, decoded)
    }

    func testIdString() throws {
        let id = JSONRPCId.string("abc-123")
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(JSONRPCId.self, from: data)
        XCTAssertEqual(id, decoded)
    }

    func testIdNull() throws {
        let id = JSONRPCId.null
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(JSONRPCId.self, from: data)
        XCTAssertEqual(id, decoded)
    }

    // MARK: - JSONRPCRequest

    func testRequestRoundtrip() throws {
        let req = JSONRPCRequest(
            id: .number(1),
            method: "tools/list",
            params: .object(["cursor": .string("abc")])
        )
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.id, .number(1))
        XCTAssertEqual(decoded.method, "tools/list")
    }

    func testRequestNoParams() throws {
        let req = JSONRPCRequest(id: .number(2), method: "ping")
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
        XCTAssertNil(decoded.params)
    }

    // MARK: - JSONRPCResponse

    func testResponseWithResult() throws {
        let resp = JSONRPCResponse(
            id: .number(1),
            result: .object(["tools": .array([])])
        )
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.id, .number(1))
        XCTAssertNotNil(decoded.result)
        XCTAssertNil(decoded.error)
    }

    func testResponseWithError() throws {
        let resp = JSONRPCResponse(
            id: .number(2),
            error: JSONRPCError(code: -32601, message: "Method not found")
        )
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        XCTAssertNotNil(decoded.error)
        XCTAssertEqual(decoded.error?.code, -32601)
        XCTAssertEqual(decoded.error?.message, "Method not found")
    }

    // MARK: - JSONRPCNotification

    func testNotificationRoundtrip() throws {
        let notif = JSONRPCNotification(
            method: "notifications/initialized",
            params: .object([:])
        )
        let data = try JSONEncoder().encode(notif)
        let decoded = try JSONDecoder().decode(JSONRPCNotification.self, from: data)
        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.method, "notifications/initialized")
    }

    // MARK: - MCPContentBlock

    func testTextContentBlock() throws {
        let block = MCPContentBlock.text("Hello, world!")
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(MCPContentBlock.self, from: data)
        if case .text(let t) = decoded {
            XCTAssertEqual(t, "Hello, world!")
        } else {
            XCTFail("Expected text block")
        }
    }

    func testImageContentBlock() throws {
        let block = MCPContentBlock.image(mimeType: "image/png", data: "base64data==")
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(MCPContentBlock.self, from: data)
        if case .image(let mime, let d) = decoded {
            XCTAssertEqual(mime, "image/png")
            XCTAssertEqual(d, "base64data==")
        } else {
            XCTFail("Expected image block")
        }
    }

    func testResourceContentBlock() throws {
        let block = MCPContentBlock.resource(uri: "file:///test.txt", mimeType: "text/plain", text: "content")
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(MCPContentBlock.self, from: data)
        if case .resource(let uri, let mime, let text) = decoded {
            XCTAssertEqual(uri, "file:///test.txt")
            XCTAssertEqual(mime, "text/plain")
            XCTAssertEqual(text, "content")
        } else {
            XCTFail("Expected resource block")
        }
    }

    // MARK: - ToolCallResult (2.1.89 backport: all content blocks)

    func testToolCallResultPreservesAllBlocks() {
        // Never truncate to first block (2.1.89 backport)
        let blocks: [MCPContentBlock] = [
            .text("Error message 1"),
            .text("Error message 2"),
            .text("Error message 3")
        ]
        let result = ToolCallResult(content: blocks, isError: true)
        XCTAssertEqual(result.content.count, 3)
        XCTAssertTrue(result.isError)
    }

    // MARK: - MCPTool

    func testMCPToolCodable() throws {
        let tool = MCPTool(
            name: "read_file",
            description: "Read a file",
            inputSchema: .object(["type": .string("object")])
        )
        let data = try JSONEncoder().encode(tool)
        let decoded = try JSONDecoder().decode(MCPTool.self, from: data)
        XCTAssertEqual(decoded.name, "read_file")
        XCTAssertEqual(decoded.description, "Read a file")
    }
}
