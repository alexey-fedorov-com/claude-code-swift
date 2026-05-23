/// Teammate task list watching (stub).
///
/// In the TypeScript reference, task list watching allows monitoring tasks
/// assigned by teammate agents via the coordinator. This is a stub.

import Foundation

// MARK: - TaskListEntry

public struct TaskListEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let priority: TaskPriority
    public let status: CoordinatorTaskStatus
    public let assignedTo: String?
    public let tags: [String]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        priority: TaskPriority = .normal,
        status: CoordinatorTaskStatus = .pending,
        assignedTo: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.status = status
        self.assignedTo = assignedTo
        self.tags = tags
        self.createdAt = createdAt
    }
}

public enum TaskPriority: String, Codable, Sendable {
    case low
    case normal
    case high
    case urgent
}

// MARK: - TaskListWatcher (stub)

/// Stub task list watcher. Provides local task tracking only.
/// Real teammate task syncing requires coordinator server infra.
public actor TaskListWatcher {

    private var tasks: [UUID: TaskListEntry] = [:]
    private var updateHandlers: [@Sendable ([TaskListEntry]) -> Void] = []
    private var isWatching = false

    public init() {}

    /// Start watching for task updates. No-op (stub).
    public func startWatching(coordinatorURL: URL? = nil) async {
        guard !isWatching else { return }
        isWatching = true
        // Real implementation would poll/subscribe to coordinator
    }

    /// Stop watching.
    public func stopWatching() {
        isWatching = false
    }

    // MARK: Local Task Management

    public func add(_ task: TaskListEntry) {
        tasks[task.id] = task
        notifyHandlers()
    }

    public func remove(id: UUID) {
        tasks.removeValue(forKey: id)
        notifyHandlers()
    }

    public func update(_ task: TaskListEntry) {
        tasks[task.id] = task
        notifyHandlers()
    }

    public var allTasks: [TaskListEntry] {
        Array(tasks.values).sorted { $0.createdAt < $1.createdAt }
    }

    public func tasks(for status: CoordinatorTaskStatus) -> [TaskListEntry] {
        allTasks.filter { $0.status == status }
    }

    public func tasks(assignedTo agentId: String) -> [TaskListEntry] {
        allTasks.filter { $0.assignedTo == agentId }
    }

    /// Register a handler to be called when tasks change.
    public func onUpdate(_ handler: @escaping @Sendable ([TaskListEntry]) -> Void) {
        updateHandlers.append(handler)
    }

    private func notifyHandlers() {
        let snapshot = allTasks
        for handler in updateHandlers {
            handler(snapshot)
        }
    }
}
