// MARK: - BootstrapState
// Ported from .reference/src/bootstrap/state.ts
//
// The TypeScript version is a module-level singleton (STATE constant).
// In Swift we model it as an actor-backed singleton to provide safe
// concurrent access without the DispatchQueue dance.
//
// TODO: extend with reference fields:
//   - telemetry counters (meter, sessionCounter, locCounter, etc.) — Task 18
//   - loggerProvider / meterProvider / tracerProvider — Task 18
//   - agentColorMap — Task 13 (AgentTool)
//   - lastAPIRequest / lastAPIRequestMessages — Task 11
//   - invokedSkills — Task 16
//   - scheduledTasksEnabled / sessionCronTasks — Task 17

import Foundation

// MARK: - SessionId / AgentId
// Branded UUID strings. In Swift we use typealiases with init helpers.

/// Uniquely identifies a Claude Code session.
public struct SessionId: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID().uuidString }
    public var description: String { rawValue }
}

/// Uniquely identifies a subagent within a session.
public struct AgentId: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static func validated(_ s: String) -> AgentId? {
        let isValid = s.range(of: #"^a(?:.+-)?[0-9a-f]{16}$"#, options: .regularExpression) != nil
        return isValid ? AgentId(rawValue: s) : nil
    }
}

// MARK: - ModelUsage

public struct ModelUsage: Codable, Sendable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadInputTokens: Int
    public var cacheCreationInputTokens: Int
    public var webSearchRequests: Int

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheReadInputTokens: Int = 0,
        cacheCreationInputTokens: Int = 0,
        webSearchRequests: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.webSearchRequests = webSearchRequests
    }
}

// MARK: - BootstrapState actor

/// Session-global state. Mirrors the TypeScript bootstrap/state.ts singleton.
/// Consumers should prefer the accessor functions below over direct property access.
public actor BootstrapState {
    public static let shared = BootstrapState()

    // MARK: Identity
    public private(set) var sessionId: SessionId = SessionId()
    public private(set) var parentSessionId: SessionId? = nil

    // MARK: Paths
    public private(set) var originalCwd: String = ""
    public private(set) var projectRoot: String = ""
    public private(set) var cwd: String = ""

    // MARK: Cost / duration
    public private(set) var totalCostUSD: Double = 0
    public private(set) var totalAPIDuration: Double = 0
    public private(set) var totalAPIDurationWithoutRetries: Double = 0
    public private(set) var totalToolDuration: Double = 0

    // MARK: Turn stats
    public private(set) var turnHookDurationMs: Double = 0
    public private(set) var turnToolDurationMs: Double = 0
    public private(set) var turnClassifierDurationMs: Double = 0
    public private(set) var turnToolCount: Int = 0
    public private(set) var turnHookCount: Int = 0
    public private(set) var turnClassifierCount: Int = 0

    // MARK: Session config
    public private(set) var startTime: Double = Date.timeIntervalSinceReferenceDate
    public private(set) var lastInteractionTime: Double = Date.timeIntervalSinceReferenceDate
    public private(set) var totalLinesAdded: Int = 0
    public private(set) var totalLinesRemoved: Int = 0
    public private(set) var isInteractive: Bool = false
    public private(set) var clientType: String = "cli"
    public private(set) var modelUsage: [String: ModelUsage] = [:]
    public private(set) var hasUnknownModelCost: Bool = false

    // MARK: Flags
    public private(set) var sessionBypassPermissionsMode: Bool = false
    public private(set) var sessionTrustAccepted: Bool = false
    public private(set) var sessionPersistenceDisabled: Bool = false
    public private(set) var hasExitedPlanMode: Bool = false
    public private(set) var isRemoteMode: Bool = false

    // MARK: Error log
    public private(set) var inMemoryErrorLog: [(error: String, timestamp: String)] = []

    // MARK: - Mutators

    public func setOriginalCwd(_ path: String) { originalCwd = path }
    public func setProjectRoot(_ path: String) { projectRoot = path }
    public func setCwd(_ path: String) { cwd = path }

    public func addCost(_ cost: Double, usage: ModelUsage, model: String) {
        modelUsage[model] = usage
        totalCostUSD += cost
    }

    public func addAPIDuration(_ duration: Double, withoutRetries: Double) {
        totalAPIDuration += duration
        totalAPIDurationWithoutRetries += withoutRetries
    }

    public func addToolDuration(_ duration: Double) {
        totalToolDuration += duration
        turnToolDurationMs += duration
        turnToolCount += 1
    }

    public func setIsInteractive(_ v: Bool) { isInteractive = v }
    public func setClientType(_ t: String) { clientType = t }
    public func setIsRemoteMode(_ v: Bool) { isRemoteMode = v }

    public func regenerateSessionId(setCurrentAsParent: Bool = false) -> SessionId {
        if setCurrentAsParent { parentSessionId = sessionId }
        sessionId = SessionId()
        return sessionId
    }

    public func appendError(error: String, timestamp: String) {
        let maxErrors = 100
        if inMemoryErrorLog.count >= maxErrors { inMemoryErrorLog.removeFirst() }
        inMemoryErrorLog.append((error: error, timestamp: timestamp))
    }
}
