/// EnterPlanModeTool stub — switch to plan-only mode. Full impl Task 15.
import Foundation
import SwiftCodeCore

public struct EnterPlanModeToolImpl: ToolHandler {
    public let name = "EnterPlanMode"
    public let description = "Switch the session into plan-only mode."
    public let inputSchema = ToolInputSchema(properties: [:], required: [])
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 15)
    }
}
