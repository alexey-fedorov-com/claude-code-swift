/// `MCP_CONNECTION_NONBLOCKING=true` support (2.1.89 backport).
///
/// When this env var is set, MCP server connections use a 5-second timeout
/// instead of the default 30 seconds. This prevents blocking startup when
/// servers are slow or unresponsive.

import Foundation

// MARK: - NonblockingConnection

public enum NonblockingConnection {

    /// Default connection timeout (30 seconds).
    public static let defaultTimeout: TimeInterval = 30.0

    /// Nonblocking connection timeout (5 seconds).
    public static let nonblockingTimeout: TimeInterval = 5.0

    /// Whether `MCP_CONNECTION_NONBLOCKING=true` is set in the environment.
    public static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["MCP_CONNECTION_NONBLOCKING"] == "true"
    }

    /// The active connection timeout based on env var.
    public static var connectionTimeout: TimeInterval {
        isEnabled ? nonblockingTimeout : defaultTimeout
    }

    /// Connect with timeout. Throws `TransportError.timeout` if exceeded.
    ///
    /// - Parameters:
    ///   - timeout: Maximum wait in seconds.
    ///   - operation: The async connection work.
    public static func withTimeout<T: Sendable>(
        _ timeout: TimeInterval? = nil,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let deadline = timeout ?? connectionTimeout
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(deadline * 1_000_000_000))
                throw TransportError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
