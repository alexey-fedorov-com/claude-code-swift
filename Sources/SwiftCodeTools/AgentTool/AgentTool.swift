/// AgentTool stub — spawns a sub-agent. Full implementation in Task 12/17.
import Foundation
import SwiftCodeCore

public struct AgentToolImpl: ToolHandler {
    public let name = "Agent"
    public let description = "Spawn a sub-agent to complete a task."
    public let inputSchema = ToolInputSchema(
        properties: [
            "prompt": PropertySchema(type: "string", description: "The task for the sub-agent."),
            "model": PropertySchema(type: "string", description: "Optional model override.")
        ],
        required: ["prompt"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
