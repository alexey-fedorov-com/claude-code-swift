/// ToolSearchTool stub — search available tools by keyword. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct ToolSearchToolImpl: ToolHandler {
    public let name = "ToolSearch"
    public let description = "Search available tools by keyword to find the right tool for a task."
    public let inputSchema = ToolInputSchema(
        properties: [
            "query": PropertySchema(type: "string", description: "Search query.")
        ],
        required: ["query"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
