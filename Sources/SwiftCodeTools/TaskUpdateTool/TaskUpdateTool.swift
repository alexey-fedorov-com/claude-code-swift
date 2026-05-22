/// TaskUpdateTool stub — update a task (todo-v2). Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct TaskUpdateToolImpl: ToolHandler {
    public let name = "TaskUpdate"
    public let description = "Update an existing task (todo-v2 feature)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "id": PropertySchema(type: "string", description: "Task ID."),
            "status": PropertySchema(type: "string", description: "New status.", enum: ["pending", "in_progress", "completed"]),
            "title": PropertySchema(type: "string", description: "New title.")
        ],
        required: ["id"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
