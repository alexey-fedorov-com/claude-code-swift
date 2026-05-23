import XCTest
@testable import SwiftCodeMCP

final class MCPConfigTests: XCTestCase {

    func testDecodeStdioServer() throws {
        let json = """
        {
            "mcpServers": {
                "filesystem": {
                    "command": "npx",
                    "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
                    "env": {"NODE_ENV": "production"}
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(MCPSettings.self, from: data)

        XCTAssertEqual(settings.servers.count, 1)
        let fs = try XCTUnwrap(settings.servers["filesystem"])
        XCTAssertEqual(fs.type, .stdio)
        XCTAssertEqual(fs.command, "npx")
        XCTAssertEqual(fs.args, ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"])
        XCTAssertEqual(fs.env?["NODE_ENV"], "production")
    }

    func testDecodeSSEServer() throws {
        let json = """
        {
            "mcpServers": {
                "remote": {
                    "url": "https://example.com/mcp/sse"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(MCPSettings.self, from: data)

        let remote = try XCTUnwrap(settings.servers["remote"])
        XCTAssertEqual(remote.type, .sse)
        XCTAssertEqual(remote.url, "https://example.com/mcp/sse")
    }

    func testDecodeHTTPServer() throws {
        let json = """
        {
            "mcpServers": {
                "api": {
                    "type": "http",
                    "url": "https://api.example.com/mcp",
                    "headers": {"Authorization": "Bearer token123"}
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(MCPSettings.self, from: data)

        let api = try XCTUnwrap(settings.servers["api"])
        XCTAssertEqual(api.type, .http)
        XCTAssertEqual(api.url, "https://api.example.com/mcp")
        XCTAssertEqual(api.headers?["Authorization"], "Bearer token123")
    }

    func testDecodeMultipleServers() throws {
        let json = """
        {
            "mcpServers": {
                "server1": {"command": "cmd1"},
                "server2": {"command": "cmd2"},
                "server3": {"url": "https://s3.example.com"}
            }
        }
        """
        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(MCPSettings.self, from: data)
        XCTAssertEqual(settings.servers.count, 3)
        XCTAssertNotNil(settings.servers["server1"])
        XCTAssertNotNil(settings.servers["server2"])
        XCTAssertNotNil(settings.servers["server3"])
    }

    func testEmptyServers() throws {
        let json = #"{"mcpServers": {}}"#
        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(MCPSettings.self, from: data)
        XCTAssertTrue(settings.servers.isEmpty)
    }

    func testExplicitStdioType() throws {
        let json = """
        {
            "mcpServers": {
                "srv": {"type": "stdio", "command": "python3", "args": ["server.py"]}
            }
        }
        """
        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(MCPSettings.self, from: data)
        let srv = try XCTUnwrap(settings.servers["srv"])
        XCTAssertEqual(srv.type, .stdio)
        XCTAssertEqual(srv.command, "python3")
    }
}
