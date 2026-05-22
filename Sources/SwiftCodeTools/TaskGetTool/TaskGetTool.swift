/// TaskGetTool stub — retrieve a task by ID (todo-v2). Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct TaskGetToolImpl: ToolHandler {
    public let name = "TaskGet"
    public let description = "Get a task by ID (todo-v2 feature)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "id": PropertySchema(type: "string", description: "Task ID.")
        ],
        required: ["id"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
