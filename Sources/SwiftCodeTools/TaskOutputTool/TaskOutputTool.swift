/// TaskOutputTool stub — emit structured output from a task agent. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct TaskOutputToolImpl: ToolHandler {
    public let name = "TaskOutput"
    public let description = "Emit structured output from a task/sub-agent."
    public let inputSchema = ToolInputSchema(
        properties: [
            "output": PropertySchema(type: "string", description: "Output payload.")
        ],
        required: ["output"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
