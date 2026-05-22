/// WebSearchTool stub — search the web. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct WebSearchToolImpl: ToolHandler {
    public let name = "WebSearch"
    public let description = "Search the web for up-to-date information."
    public let inputSchema = ToolInputSchema(
        properties: [
            "query": PropertySchema(type: "string", description: "The search query.")
        ],
        required: ["query"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
