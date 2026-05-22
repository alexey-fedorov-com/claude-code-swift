/// LSPTool stub — query a Language Server Protocol server. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct LSPToolImpl: ToolHandler {
    public let name = "LSP"
    public let description = "Query a Language Server Protocol server for IDE intelligence."
    public let inputSchema = ToolInputSchema(
        properties: [
            "method": PropertySchema(type: "string", description: "LSP method name."),
            "params": PropertySchema(type: "string", description: "JSON-encoded LSP params.")
        ],
        required: ["method"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
