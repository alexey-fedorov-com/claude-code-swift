/// ExitPlanModeTool stub — exit plan mode and begin execution. Full impl Task 15.
import Foundation
import SwiftCodeCore

public struct ExitPlanModeToolImpl: ToolHandler {
    public let name = "ExitPlanMode"
    public let description = "Exit plan mode and begin executing the plan."
    public let inputSchema = ToolInputSchema(
        properties: [
            "plan": PropertySchema(type: "string", description: "The confirmed plan to execute.")
        ],
        required: ["plan"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 15)
    }
}
