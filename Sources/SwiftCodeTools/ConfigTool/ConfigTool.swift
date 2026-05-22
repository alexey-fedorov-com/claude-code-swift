/// ConfigTool stub — read/write Claude Code config (ant-only). Full impl Task 7.
import Foundation
import SwiftCodeCore

public struct ConfigToolImpl: ToolHandler {
    public let name = "Config"
    public let description = "Read or write Claude Code configuration (ant-only)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "key": PropertySchema(type: "string", description: "Config key."),
            "value": PropertySchema(type: "string", description: "Config value (omit to read).")
        ],
        required: ["key"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 7)
    }
}
