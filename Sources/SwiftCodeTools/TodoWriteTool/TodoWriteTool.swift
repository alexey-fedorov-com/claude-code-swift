/// TodoWriteTool — manage an in-memory todo list keyed by session.
///
/// Reference: .reference/src/tools/TodoWriteTool/TodoWriteTool.ts
///
/// The todo list is kept in a process-global actor (TodoStore). In the reference
/// implementation it's stored in appState; here we use a module-level actor for
/// simplicity as the session/multi-agent scoping isn't wired yet.

import Foundation
import SwiftCodeCore

// MARK: - Todo model

/// A single todo item.
public struct TodoItem: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable {
        case pending, inProgress = "in_progress", completed
    }

    public let id: String
    public let content: String
    public let status: Status
    /// Priority/ordering hint. 1 = highest.
    public let priority: Int?

    public init(id: String, content: String, status: Status, priority: Int? = nil) {
        self.id = id
        self.content = content
        self.status = status
        self.priority = priority
    }
}

// MARK: - TodoStore actor

/// In-memory todo store. Lives for the duration of the process.
public actor TodoStore {
    public static let shared = TodoStore()
    private var todos: [String: [TodoItem]] = [:]

    private init() {}

    public func set(sessionId: String, items: [TodoItem]) {
        todos[sessionId] = items
    }

    public func get(sessionId: String) -> [TodoItem] {
        todos[sessionId] ?? []
    }

    public func reset(sessionId: String) {
        todos.removeValue(forKey: sessionId)
    }
}

// MARK: - TodoWriteTool

public struct TodoWriteTool: ToolHandler {
    public let name = "TodoWrite"
    public let description = """
        Use this tool to create and manage a structured todo list for tracking \
        tasks and their completion status.
        """

    public let inputSchema = ToolInputSchema(
        properties: [
            "todos": PropertySchema(
                type: "array",
                description: "The updated todo list. Replaces the current list entirely.",
                items: PropertySchemaItems(
                    type: "object",
                    properties: [
                        "id": PropertySchema(type: "string", description: "Unique todo ID."),
                        "content": PropertySchema(type: "string", description: "Todo description."),
                        "status": PropertySchema(
                            type: "string",
                            description: "Status: pending, in_progress, or completed.",
                            enum: ["pending", "in_progress", "completed"]
                        ),
                        "priority": PropertySchema(type: "integer", description: "Priority (1=highest).")
                    ],
                    required: ["id", "content", "status"]
                )
            )
        ],
        required: ["todos"]
    )

    /// Session identifier used to scope the todo list.
    public let sessionId: String

    public init(sessionId: String = "default") {
        self.sessionId = sessionId
    }

    public func execute(input: [String: JSONValue]) async throws -> String {
        guard let todosRaw = input["todos"]?.arrayValue else {
            throw ToolError.invalidInput(tool: name, message: "todos must be an array")
        }

        var items: [TodoItem] = []
        for raw in todosRaw {
            guard let obj = raw.objectValue,
                  let id = obj["id"]?.stringValue,
                  let content = obj["content"]?.stringValue,
                  let statusStr = obj["status"]?.stringValue,
                  let status = TodoItem.Status(rawValue: statusStr) else {
                throw ToolError.invalidInput(tool: name, message: "each todo must have id, content, and status")
            }
            let priority = obj["priority"]?.intValue
            items.append(TodoItem(id: id, content: content, status: status, priority: priority))
        }

        await TodoStore.shared.set(sessionId: sessionId, items: items)

        // Build a readable summary
        let pending = items.filter { $0.status == .pending }.count
        let inProgress = items.filter { $0.status == .inProgress }.count
        let done = items.filter { $0.status == .completed }.count
        let total = items.count

        var lines = ["Todos updated (\(total) items: \(inProgress) in-progress, \(pending) pending, \(done) completed)."]
        for item in items {
            let bullet: String
            switch item.status {
            case .pending:    bullet = "[ ]"
            case .inProgress: bullet = "[~]"
            case .completed:  bullet = "[x]"
            }
            lines.append("\(bullet) \(item.content)")
        }
        return lines.joined(separator: "\n")
    }
}
