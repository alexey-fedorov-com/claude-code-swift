/// TaskCreateTool stub — create a task in todo-v2 mode. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct TaskCreateToolImpl: ToolHandler {
    public let name = "TaskCreate"
    public let description = "Create a new task (todo-v2 feature)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "title": PropertySchema(type: "string", description: "Task title."),
            "description": PropertySchema(type: "string", description: "Task description.")
        ],
        required: ["title"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
