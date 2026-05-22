/// SendMessageTool stub — send a message to a peer agent. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct SendMessageToolImpl: ToolHandler {
    public let name = "SendMessage"
    public let description = "Send a message to a peer agent in multi-agent mode."
    public let inputSchema = ToolInputSchema(
        properties: [
            "to": PropertySchema(type: "string", description: "Recipient agent ID."),
            "message": PropertySchema(type: "string", description: "Message content.")
        ],
        required: ["to", "message"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
