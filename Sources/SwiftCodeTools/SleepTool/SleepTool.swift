/// SleepTool stub — pause execution for a given duration (KAIROS/PROACTIVE). Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct SleepToolImpl: ToolHandler {
    public let name = "Sleep"
    public let description = "Pause execution for a specified number of seconds (feature-gated)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "seconds": PropertySchema(type: "number", description: "Duration to sleep in seconds.")
        ],
        required: ["seconds"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
