/// PermissionRule — `defer` decision support for PreToolUse hooks.
///
/// 2.1.89 backport: headless sessions can pause via `defer` and resume via `--resume`.
/// Mirrors the PermissionRule changes from .reference/src/utils/permissions/PermissionRule.ts
/// and .reference/src/utils/hooks/hooks.ts (defer decision handling).

import Foundation

// MARK: - PermissionDecision

/// The decision returned by a hook or permission rule for a tool use request.
public enum PermissionDecision: Sendable, Equatable {
    /// Approve the tool use — proceed without prompting.
    case approve

    /// Block the tool use and return a message to the model.
    case block(message: String)

    /// 2.1.89 backport: Defer the decision — pause the session.
    /// In headless mode the session is suspended; it can be resumed via `--resume`.
    /// The message is shown to the operator.
    case `defer`(message: String)

    /// No opinion — fall through to the next rule or default behaviour.
    case noop
}

// MARK: - PermissionDecision helpers

extension PermissionDecision {
    /// Returns true when the decision is `defer`.
    public var isDeferred: Bool {
        if case .defer = self { return true }
        return false
    }

    /// Returns true when the decision is `block`.
    public var isBlocked: Bool {
        if case .block = self { return true }
        return false
    }

    /// Returns true when the decision is `approve`.
    public var isApproved: Bool {
        if case .approve = self { return true }
        return false
    }
}

// MARK: - HookDecisionParser

/// Parses a hook process exit code and stdout into a `PermissionDecision`.
///
/// Exit code semantics (matching the reference implementation):
/// - 0: noop (continue)
/// - 1: block — stderr/stdout used as the block message
/// - 2: block — stderr/stdout used as the block message (hard error)
/// - Exit code 0 with JSON output containing `decision: "defer"`: defer
/// - Exit code 0 with JSON output containing `decision: "block"`: block
/// - Exit code 0 with JSON output containing `decision: "approve"`: approve
public enum HookDecisionParser {
    /// Parses hook process output into a `PermissionDecision`.
    public static func parse(
        exitCode: Int32,
        stdout: String,
        stderr: String
    ) -> PermissionDecision {
        switch exitCode {
        case 0:
            // Try to parse JSON decision from stdout
            return parseJSON(stdout) ?? .noop
        case 1, 2:
            let msg = stdout.isEmpty ? stderr : stdout
            return .block(message: msg.isEmpty ? "Hook blocked tool use (exit \(exitCode))" : msg)
        default:
            // Non-zero, non-1/2: treat as error/noop
            return .noop
        }
    }

    // MARK: - Private

    /// Attempts to parse a JSON `{ decision: "approve" | "block" | "defer", message?: "..." }` payload.
    private static func parseJSON(_ output: String) -> PermissionDecision? {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let decision = json["decision"] as? String
        else {
            return nil
        }
        let message = json["message"] as? String ?? json["reason"] as? String ?? ""
        switch decision {
        case "approve": return .approve
        case "block": return .block(message: message)
        case "defer": return .defer(message: message)
        default: return nil
        }
    }
}
