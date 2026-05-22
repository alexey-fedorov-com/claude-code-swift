/// ListMcpResourcesTool stub — list resources from an MCP server. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct ListMcpResourcesToolImpl: ToolHandler {
    public let name = "ListMcpResources"
    public let description = "List available resources from a connected MCP server."
    public let inputSchema = ToolInputSchema(
        properties: [
            "server_name": PropertySchema(type: "string", description: "MCP server name.")
        ],
        required: ["server_name"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
