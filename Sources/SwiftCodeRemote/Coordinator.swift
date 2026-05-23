/// Coordinator mode types.
///
/// COORDINATOR_MODE is an enabled feature flag, but the actual coordinator
/// infrastructure is server-side. These are type stubs for the client side.
/// The coordinator manages multi-agent task orchestration.

import Foundation

// MARK: - CoordinatorMode

/// Whether coordinator mode is active. The feature flag is enabled but
/// actual coordinator functionality requires server-side infrastructure.
public let COORDINATOR_MODE_ENABLED = false  // server-side infra not present

// MARK: - CoordinatorTask

/// A task managed by the coordinator.
public struct CoordinatorTask: Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let status: CoordinatorTaskStatus
    public let assignedAgentId: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        status: CoordinatorTaskStatus = .pending,
        assignedAgentId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.assignedAgentId = assignedAgentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum CoordinatorTaskStatus: String, Codable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case failed
    case cancelled
}

// MARK: - CoordinatorConfig

public struct CoordinatorConfig: Sendable {
    /// The coordinator server endpoint.
    public let endpoint: URL?
    /// The agent ID for this session.
    public let agentId: String

    public init(endpoint: URL? = nil, agentId: String = UUID().uuidString) {
        self.endpoint = endpoint
        self.agentId = agentId
    }
}

// MARK: - Coordinator (stub)

/// Stub coordinator actor. Provides task type infrastructure.
/// Actual multi-agent coordination is server-side.
public actor Coordinator {

    public let config: CoordinatorConfig
    private var tasks: [UUID: CoordinatorTask] = [:]

    public init(config: CoordinatorConfig = CoordinatorConfig()) {
        self.config = config
    }

    /// Connect to the coordinator. No-op (server-side infra not present).
    public func connect() async throws {
        guard COORDINATOR_MODE_ENABLED else { return }
        // Not implemented
    }

    /// Get all tasks.
    public func listTasks() -> [CoordinatorTask] {
        Array(tasks.values).sorted { $0.createdAt < $1.createdAt }
    }

    /// Add a task locally (for offline/stub use).
    public func addTask(_ task: CoordinatorTask) {
        tasks[task.id] = task
    }

    /// Update task status locally.
    public func updateStatus(_ id: UUID, status: CoordinatorTaskStatus) {
        if var task = tasks[id] {
            task = CoordinatorTask(
                id: task.id,
                title: task.title,
                description: task.description,
                status: status,
                assignedAgentId: task.assignedAgentId,
                createdAt: task.createdAt,
                updatedAt: Date()
            )
            tasks[id] = task
        }
    }
}
