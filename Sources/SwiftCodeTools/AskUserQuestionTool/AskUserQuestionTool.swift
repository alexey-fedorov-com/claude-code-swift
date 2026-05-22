/// AskUserQuestionTool stub — ask the user a clarifying question. Full impl Task 15.
import Foundation
import SwiftCodeCore

public struct AskUserQuestionToolImpl: ToolHandler {
    public let name = "AskUserQuestion"
    public let description = "Ask the user a clarifying question and wait for a response."
    public let inputSchema = ToolInputSchema(
        properties: [
            "question": PropertySchema(type: "string", description: "The question to ask the user."),
            "options": PropertySchema(type: "array", description: "Optional list of choices.")
        ],
        required: ["question"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 15)
    }
}
