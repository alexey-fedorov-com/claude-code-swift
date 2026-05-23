/// HookEvent — hook event types and payload structs.
///
/// Mirrors hook event definitions from:
/// - .reference/src/schemas/hooks.ts
/// - .reference/src/utils/hooks/hookEvents.ts
/// - .reference/src/entrypoints/agentSdkTypes.ts (HOOK_EVENTS)
///
/// 2.1.89 backport: adds PermissionDenied event type.

import Foundation
import SwiftCodeCore

// MARK: - HookEventType

/// All supported hook event types.
/// These match the HOOK_EVENTS array in the TypeScript reference.
public enum HookEventType: String, Codable, CaseIterable, Sendable {
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case notification = "Notification"
    case stop = "Stop"
    case subagentStop = "SubagentStop"
    case preCompact = "PreCompact"
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case userPromptSubmit = "UserPromptSubmit"
    case prompt = "Prompt"
    /// 2.1.89 backport: PermissionDenied hook event
    case permissionDenied = "PermissionDenied"
}

// MARK: - HookEvent

/// A hook event dispatched by the runtime to registered hook handlers.
public struct HookEvent: Sendable {
    /// The event type.
    public let type: HookEventType
    /// Arbitrary payload data — tool name, input, output, etc.
    public let payload: [String: JSONValue]
    /// Session identifier — passed to hook processes as `$SESSION_ID`.
    public let sessionId: String
    /// Wall clock time of the event.
    public let timestamp: Date

    public init(
        type: HookEventType,
        payload: [String: JSONValue] = [:],
        sessionId: String,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.payload = payload
        self.sessionId = sessionId
        self.timestamp = timestamp
    }
}

// MARK: - HookExecutionEvent (event bus)

/// Events emitted into the hook event bus (distinct from HookEvent dispatched *to* hooks).
/// These track the lifecycle of individual hook executions.
public enum HookExecutionEvent: Sendable {
    case started(hookId: String, hookName: String, hookEvent: String)
    case progress(hookId: String, hookName: String, hookEvent: String, stdout: String, stderr: String)
    case response(hookId: String, hookName: String, hookEvent: String, output: String, stdout: String, stderr: String, exitCode: Int32?, outcome: HookOutcome)
}

public enum HookOutcome: String, Sendable {
    case success
    case error
    case cancelled
}
