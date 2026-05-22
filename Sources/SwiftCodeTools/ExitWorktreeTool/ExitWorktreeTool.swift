/// ExitWorktreeTool stub — exit the current git worktree context. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct ExitWorktreeToolImpl: ToolHandler {
    public let name = "ExitWorktree"
    public let description = "Exit the current git worktree context."
    public let inputSchema = ToolInputSchema(properties: [:], required: [])
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
