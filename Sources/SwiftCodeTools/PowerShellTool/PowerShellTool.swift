/// PowerShellTool stub — execute PowerShell commands (Windows only). Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct PowerShellToolImpl: ToolHandler {
    public let name = "PowerShell"
    public let description = "Execute a PowerShell command (Windows only)."
    public let inputSchema = ToolInputSchema(
        properties: [
            "command": PropertySchema(type: "string", description: "The PowerShell command to run."),
            "timeout": PropertySchema(type: "integer", description: "Timeout in milliseconds.")
        ],
        required: ["command"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
