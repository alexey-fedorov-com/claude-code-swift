/// EnterWorktreeTool stub — enter a git worktree context. Full impl Task 17.
import Foundation
import SwiftCodeCore

public struct EnterWorktreeToolImpl: ToolHandler {
    public let name = "EnterWorktree"
    public let description = "Enter a git worktree for isolated development."
    public let inputSchema = ToolInputSchema(
        properties: [
            "worktree_path": PropertySchema(type: "string", description: "Path to the worktree.")
        ],
        required: ["worktree_path"]
    )
    public init() {}
    public func execute(input: [String: JSONValue]) async throws -> String {
        throw ToolError.notImplemented(tool: name, plannedTask: 17)
    }
}
