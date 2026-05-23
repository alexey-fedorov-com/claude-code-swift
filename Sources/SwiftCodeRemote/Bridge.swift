/// Bridge mode types (BRIDGE_MODE is disabled).
///
/// The TypeScript reference supports a bridge mode for connecting between
/// Claude Code instances. In this Swift port it is not enabled — these are
/// type stubs only.

import Foundation

// MARK: - BridgeMode

/// Whether bridge mode is active. Always false in the Swift port.
public let BRIDGE_MODE_ENABLED = false

// MARK: - BridgeMessage

/// A message routed through the bridge.
public struct BridgeMessage: Codable, Sendable {
    public enum Direction: String, Codable, Sendable {
        case toParent
        case toChild
    }

    public let id: UUID
    public let direction: Direction
    public let payload: Data
    public let timestamp: Date

    public init(id: UUID = UUID(), direction: Direction, payload: Data, timestamp: Date = Date()) {
        self.id = id
        self.direction = direction
        self.payload = payload
        self.timestamp = timestamp
    }
}

// MARK: - BridgeConfig

public struct BridgeConfig: Sendable {
    public let parentSessionId: String?
    public let childSessionId: String?

    public init(parentSessionId: String? = nil, childSessionId: String? = nil) {
        self.parentSessionId = parentSessionId
        self.childSessionId = childSessionId
    }
}

// MARK: - Bridge (stub)

/// Stub bridge actor. Does nothing — BRIDGE_MODE is disabled.
public actor Bridge {

    public let config: BridgeConfig
    public private(set) var isRunning = false

    public init(config: BridgeConfig = BridgeConfig()) {
        self.config = config
    }

    /// Start bridge. Always a no-op (BRIDGE_MODE disabled).
    public func start() async {
        guard BRIDGE_MODE_ENABLED else { return }
        // Not implemented
    }

    public func stop() async {
        isRunning = false
    }

    /// Send a message through the bridge. No-op if disabled.
    public func send(_ message: BridgeMessage) async {
        guard BRIDGE_MODE_ENABLED else { return }
        // Not implemented
    }
}
