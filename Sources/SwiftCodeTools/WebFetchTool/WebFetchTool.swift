/// WebFetchTool stub — fetch a URL and return its content. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct WebFetchToolImpl: ToolHandler {
    public let name = "WebFetch"
    public let description = "Fetch a URL and return its text content."
    public let inputSchema = ToolInputSchema(
        properties: [
            "url": PropertySchema(type: "string", description: "The URL to fetch."),
            "prompt": PropertySchema(type: "string", description: "Optional prompt to focus the extraction.")
        ],
        required: ["url"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
