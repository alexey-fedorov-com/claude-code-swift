/// HookRunner — executes hooks for events, spawning processes via ProcessRunner.
///
/// Mirrors the hook execution logic from:
/// - .reference/src/utils/hooks/hooks.ts
/// - .reference/src/utils/hooks/execAgentHook.ts  (shell hooks)
/// - .reference/src/utils/hooks/execHttpHook.ts    (HTTP hooks — basic shape only, TODO: retry)
/// - .reference/src/utils/hooks/execPromptHook.ts  (prompt hooks — HOOK_PROMPTS flag)
///
/// 2.1.89 backports:
/// - `defer` decision support (headless pause/resume)
/// - Hook output >50K written to disk
///
/// Design: actor for thread-safe mutable config state.

import Foundation
import SwiftCodeCore
import SwiftCodeNative

// MARK: - HookResult

/// The result of executing a single hook command.
public struct HookResult: Sendable {
    /// The permission decision derived from the hook's output.
    public let decision: PermissionDecision
    /// If hook output exceeded 50K, this is the temp file URL.
    public let outputPath: URL?
    /// Short preview of the hook output (full output if small enough).
    public let outputPreview: String?
    /// Raw exit code from the hook process.
    public let exitCode: Int32?

    public init(
        decision: PermissionDecision,
        outputPath: URL? = nil,
        outputPreview: String? = nil,
        exitCode: Int32? = nil
    ) {
        self.decision = decision
        self.outputPath = outputPath
        self.outputPreview = outputPreview
        self.exitCode = exitCode
    }
}

// MARK: - HookRunnerError

public enum HookRunnerError: Error, LocalizedError {
    case commandMissing
    case urlMissing
    case promptMissing
    case timeout(commandDescription: String)
    case unsupportedHookType(String)

    public var errorDescription: String? {
        switch self {
        case .commandMissing:       return "Hook is missing required 'command' field"
        case .urlMissing:           return "HTTP hook is missing required 'url' field"
        case .promptMissing:        return "Prompt hook is missing required 'prompt' field"
        case .timeout(let cmd):     return "Hook timed out: \(cmd)"
        case .unsupportedHookType(let t): return "Unsupported hook type: \(t)"
        }
    }
}

// MARK: - HookRunner

/// Actor that dispatches `HookEvent`s to configured hook commands.
///
/// Usage:
/// ```swift
/// let runner = HookRunner(processRunner: ProcessRunner(), config: config)
/// let results = try await runner.dispatch(event)
/// ```
public actor HookRunner {
    private let processRunner: ProcessRunner
    private var config: HookConfig

    /// Default hook execution timeout in seconds (matches reference: 60s).
    public static let defaultTimeoutSeconds: TimeInterval = 60

    public init(processRunner: ProcessRunner, config: HookConfig) {
        self.processRunner = processRunner
        self.config = config
    }

    /// Updates the hook configuration (e.g. after settings reload).
    public func updateConfig(_ newConfig: HookConfig) {
        self.config = newConfig
    }

    // MARK: - Dispatch

    /// Dispatches a hook event, running all matching hooks in sequence.
    ///
    /// - Returns: An array of `HookResult` — one per hook command that ran.
    public func dispatch(_ event: HookEvent) async throws -> [HookResult] {
        let matchers = config.matchers(for: event.type)
        guard !matchers.isEmpty else { return [] }

        var results: [HookResult] = []

        for matcher in matchers {
            // Check if this matcher applies to the event
            guard matcherApplies(matcher, to: event) else { continue }

            for hookCmd in matcher.hooks {
                // Skip async hooks in this basic runner (they run fire-and-forget)
                let isAsync = hookCmd.async == true || hookCmd.asyncRewake == true
                if isAsync {
                    Task {
                        _ = try? await executeHook(hookCmd, event: event)
                    }
                    continue
                }

                let result = try await executeHook(hookCmd, event: event)
                results.append(result)

                // If a hook blocks or defers, stop processing further hooks
                if result.decision.isBlocked || result.decision.isDeferred {
                    return results
                }
            }
        }

        return results
    }

    // MARK: - Private

    /// Checks whether a matcher pattern applies to the given event payload.
    private func matcherApplies(_ matcher: HookMatcher, to event: HookEvent) -> Bool {
        guard let pattern = matcher.matcher, !pattern.isEmpty else {
            return true // No pattern = match everything
        }

        // For tool events, match against the tool_name in the payload
        if let toolName = event.payload["tool_name"],
           case .string(let name) = toolName {
            return fnmatch(pattern, name) || name == pattern
        }

        return true
    }

    /// Simple fnmatch-like glob matching (handles * wildcard).
    private func fnmatch(_ pattern: String, _ string: String) -> Bool {
        if pattern == "*" { return true }
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return string.hasPrefix(prefix)
        }
        if pattern.hasPrefix("*") {
            let suffix = String(pattern.dropFirst())
            return string.hasSuffix(suffix)
        }
        return pattern == string
    }

    /// Routes a single hook command to the appropriate executor.
    private func executeHook(_ hook: HookCommand, event: HookEvent) async throws -> HookResult {
        switch hook.type {
        case "command":
            return try await executeCommandHook(hook, event: event)
        case "prompt":
            return try await executePromptHook(hook, event: event)
        case "http":
            return try await executeHTTPHook(hook, event: event)
        default:
            throw HookRunnerError.unsupportedHookType(hook.type)
        }
    }

    // MARK: - Command hook

    private func executeCommandHook(_ hook: HookCommand, event: HookEvent) async throws -> HookResult {
        guard let command = hook.command, !command.isEmpty else {
            throw HookRunnerError.commandMissing
        }

        let timeout = hook.timeout.map { TimeInterval($0) } ?? Self.defaultTimeoutSeconds
        let inputJSON = makeInputJSON(for: event)

        let result = try await processRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", command],
            environment: makeEnvironment(for: event),
            stdin: inputJSON,
            timeout: timeout
        )

        let combinedOutput = result.stdout + result.stderr
        let (preview, path) = try HookOutput.process(combinedOutput, sessionId: event.sessionId)
        let decision = HookDecisionParser.parse(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr
        )

        return HookResult(
            decision: decision,
            outputPath: path,
            outputPreview: preview,
            exitCode: result.exitCode
        )
    }

    // MARK: - Prompt hook

    /// Executes a prompt hook (HOOK_PROMPTS feature flag = enabled).
    /// TODO: Wire to actual LLM query; currently returns noop.
    private func executePromptHook(_ hook: HookCommand, event: HookEvent) async throws -> HookResult {
        guard hook.prompt != nil else {
            throw HookRunnerError.promptMissing
        }

        // HOOK_PROMPTS is enabled in FeatureFlags.current
        // Full implementation requires wiring to the API layer — not done here.
        // TODO: call API with hook.prompt + makeInputJSON(for:event)
        return HookResult(decision: .noop, outputPreview: "[prompt hook — TODO: wire to API]")
    }

    // MARK: - HTTP hook

    /// Executes an HTTP hook.
    /// TODO: Implement retry logic and proper HTTP client integration.
    private func executeHTTPHook(_ hook: HookCommand, event: HookEvent) async throws -> HookResult {
        guard let urlString = hook.url, !urlString.isEmpty else {
            throw HookRunnerError.urlMissing
        }

        // TODO: Use AsyncHTTPClient to POST inputJSON to urlString.
        // Retry logic is complex — deferred per pragmatic scope guidance.
        return HookResult(decision: .noop, outputPreview: "[http hook — TODO: implement HTTP call to \(urlString)]")
    }

    // MARK: - Helpers

    /// Builds the JSON string passed to hook processes via stdin.
    private func makeInputJSON(for event: HookEvent) -> String {
        var dict: [String: Any] = [
            "hook_event_name": event.type.rawValue,
            "session_id": event.sessionId,
        ]

        // Merge payload fields
        for (key, value) in event.payload {
            dict[key] = jsonValueToAny(value)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
              let str = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return str
    }

    /// Builds the environment for hook subprocesses.
    private func makeEnvironment(for event: HookEvent) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["CLAUDE_SESSION_ID"] = event.sessionId
        env["CLAUDE_HOOK_EVENT"] = event.type.rawValue
        return env
    }

    /// Converts JSONValue to a plain Swift Any for JSONSerialization.
    private func jsonValueToAny(_ value: JSONValue) -> Any {
        switch value {
        case .null:            return NSNull()
        case .bool(let b):    return b
        case .int(let i):     return i
        case .double(let d):  return d
        case .string(let s):  return s
        case .array(let a):   return a.map { jsonValueToAny($0) }
        case .object(let o):  return o.mapValues { jsonValueToAny($0) }
        }
    }
}
