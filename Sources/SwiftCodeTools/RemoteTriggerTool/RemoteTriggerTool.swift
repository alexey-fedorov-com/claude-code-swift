/// RemoteTriggerTool stub — trigger a remote action/webhook. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct RemoteTriggerToolImpl: ToolHandler {
    public let name = "RemoteTrigger"
    public let description = "Trigger a remote action or webhook (feature-gated)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "url": PropertySchema(type: "string", description: "Webhook or trigger URL."),
            "payload": PropertySchema(type: "string", description: "JSON payload.")
        ],
        required: ["url"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
