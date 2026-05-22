/// BriefTool stub — write a compact internal note/brief. Full impl Task 16.
import Foundation
import SwiftCodeCore

public struct BriefToolImpl: ToolHandler {
    public let name = "Brief"
    public let description = "Write a brief internal note summarising findings."
    public let inputSchema = ToolInputSchema(
        properties: [
            "brief": PropertySchema(type: "string", description: "The brief text.")
        ],
        required: ["brief"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 16)
    }
}
