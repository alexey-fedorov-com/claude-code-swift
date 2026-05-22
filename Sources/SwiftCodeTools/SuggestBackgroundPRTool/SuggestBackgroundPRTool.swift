/// SuggestBackgroundPRTool stub — suggest a PR in background mode (ant-only). Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct SuggestBackgroundPRToolImpl: ToolHandler {
    public let name = "SuggestBackgroundPR"
    public let description = "Suggest a pull request for background session work (ant-only)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "title": PropertySchema(type: "string", description: "PR title."),
            "body": PropertySchema(type: "string", description: "PR description.")
        ],
        required: ["title"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
