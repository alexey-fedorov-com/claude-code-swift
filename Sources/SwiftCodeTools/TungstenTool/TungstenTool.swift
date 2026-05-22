/// TungstenTool stub — Anthropic-internal debugging tool (ant-only). Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct TungstenToolImpl: ToolHandler {
    public let name = "Tungsten"
    public let description = "Internal Anthropic debugging tool (ant-only, not available externally)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "action": PropertySchema(type: "string", description: "Debugging action to perform.")
        ],
        required: ["action"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
