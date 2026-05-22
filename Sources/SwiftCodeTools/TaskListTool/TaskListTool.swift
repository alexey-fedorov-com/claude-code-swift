/// TaskListTool stub — list all tasks (todo-v2). Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct TaskListToolImpl: ToolHandler {
    public let name = "TaskList"
    public let description = "List all tasks (todo-v2 feature)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "status": PropertySchema(type: "string", description: "Filter by status.", enum: ["pending", "in_progress", "completed"])
        ],
        required: []
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
