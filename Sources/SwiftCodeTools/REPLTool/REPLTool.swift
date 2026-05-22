/// REPLTool stub — ant-only VM sandbox tool. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct REPLToolImpl: ToolHandler {
    public let name = "REPL"
    public let description = "Execute code in an isolated VM sandbox (ant-only)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "code": PropertySchema(type: "string", description: "Code to execute in the REPL.")
        ],
        required: ["code"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
