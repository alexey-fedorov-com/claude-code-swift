/// ReadMcpResourceTool stub — read a resource from an MCP server. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct ReadMcpResourceToolImpl: ToolHandler {
    public let name = "ReadMcpResource"
    public let description = "Read a resource from a connected MCP server."
    public let inputSchema = ToolInputSchema(
        properties: [
            "server_name": PropertySchema(type: "string", description: "MCP server name."),
            "uri": PropertySchema(type: "string", description: "Resource URI.")
        ],
        required: ["server_name", "uri"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
