/// SyntheticOutputTool stub — inject a synthetic tool result. Full impl Task 15.
import Foundation
import SwiftCodeCore

public struct SyntheticOutputToolImpl: ToolHandler {
    public let name = "SyntheticOutput"
    public let description = "Inject a synthetic tool result into the conversation."
    public let inputSchema = ToolInputSchema(
        properties: [
            "content": PropertySchema(type: "string", description: "Synthetic content to inject.")
        ],
        required: ["content"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 15)
    }
}
