/// SkillTool stub — invoke a bundled or plugin skill/slash command. Full impl Task 16.
import Foundation
import SwiftCodeCore

public struct SkillToolImpl: ToolHandler {
    public let name = "Skill"
    public let description = "Invoke a bundled skill or plugin slash command."
    public let inputSchema = ToolInputSchema(
        properties: [
            "name": PropertySchema(type: "string", description: "Skill or command name."),
            "args": PropertySchema(type: "string", description: "Arguments to pass.")
        ],
        required: ["name"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 16)
    }
}
