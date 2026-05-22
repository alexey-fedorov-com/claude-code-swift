/// ScheduleCronTool stub — schedule recurring tasks (CronCreate/Delete/List). Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct ScheduleCronToolImpl: ToolHandler {
    public let name = "ScheduleCron"
    public let description = "Create, list, or delete scheduled cron tasks."
    public let inputSchema = ToolInputSchema(
        properties: [
            "action": PropertySchema(type: "string", description: "create, list, or delete.", enum: ["create", "list", "delete"]),
            "schedule": PropertySchema(type: "string", description: "Cron expression (create only)."),
            "command": PropertySchema(type: "string", description: "Command to run (create only)."),
            "id": PropertySchema(type: "string", description: "Cron ID (delete only).")
        ],
        required: ["action"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
