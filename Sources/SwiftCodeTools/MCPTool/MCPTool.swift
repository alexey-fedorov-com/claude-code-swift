/// MCPTool stub — invoke an arbitrary MCP tool. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct MCPToolImpl: ToolHandler {
    public let name = "MCP"
    public let description = "Invoke a tool provided by a connected MCP server."
    public let inputSchema = ToolInputSchema(
        properties: [
            "server": PropertySchema(type: "string", description: "MCP server name."),
            "tool": PropertySchema(type: "string", description: "Tool name on the server."),
            "input": PropertySchema(type: "string", description: "JSON-encoded tool input.")
        ],
        required: ["server", "tool"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
