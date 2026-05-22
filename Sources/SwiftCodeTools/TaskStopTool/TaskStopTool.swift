/// TaskStopTool stub — stop the current agent task. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct TaskStopToolImpl: ToolHandler {
    public let name = "TaskStop"
    public let description = "Stop the current task/agent execution."
    public let inputSchema = ToolInputSchema(
        properties: [
            "reason": PropertySchema(type: "string", description: "Reason for stopping.")
        ],
        required: []
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
