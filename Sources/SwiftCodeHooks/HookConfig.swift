/// HookConfig — Codable hooks configuration loaded from settings.json.
///
/// Mirrors the hook schemas from .reference/src/schemas/hooks.ts.
/// The settings.json `hooks` field is a dictionary keyed by event type,
/// each value is an array of matchers containing hook command arrays.

import Foundation
import SwiftCodeCore

// MARK: - HookCommand

/// A single executable hook — either a shell command, prompt, or HTTP call.
public struct HookCommand: Codable, Sendable {
    /// Hook type: "command" | "prompt" | "http"
    public var type: String

    // MARK: Command fields
    /// Shell command to execute (type == "command")
    public var command: String?
    /// Shell type: "bash" | "powershell" (defaults to bash)
    public var shell: String?
    /// Runs once then removes itself
    public var once: Bool?
    /// Background (non-blocking) execution
    public var async: Bool?
    /// Background + wakes model on exit code 2
    public var asyncRewake: Bool?

    // MARK: Prompt fields
    /// LLM prompt body (type == "prompt")
    public var prompt: String?
    /// Model override for prompt hooks
    public var model: String?

    // MARK: HTTP fields
    /// URL to POST to (type == "http")
    public var url: String?

    // MARK: Shared fields
    /// Optional permission-rule filter (e.g. "Bash(git *)")
    public var `if`: String?
    /// Timeout in seconds
    public var timeout: Int?
    /// Custom spinner message while running
    public var statusMessage: String?

    public init(
        type: String,
        command: String? = nil,
        shell: String? = nil,
        once: Bool? = nil,
        async: Bool? = nil,
        asyncRewake: Bool? = nil,
        prompt: String? = nil,
        model: String? = nil,
        url: String? = nil,
        if condition: String? = nil,
        timeout: Int? = nil,
        statusMessage: String? = nil
    ) {
        self.type = type
        self.command = command
        self.shell = shell
        self.once = once
        self.async = async
        self.asyncRewake = asyncRewake
        self.prompt = prompt
        self.model = model
        self.url = url
        self.if = condition
        self.timeout = timeout
        self.statusMessage = statusMessage
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, command, shell, once, async = "async", asyncRewake
        case prompt, model, url
        case `if` = "if"
        case timeout, statusMessage
    }
}

// MARK: - HookMatcher

/// A matcher+hooks pair. The matcher filters which tool calls trigger these hooks.
/// For PreToolUse/PostToolUse the matcher is a tool name or glob pattern.
public struct HookMatcher: Codable, Sendable {
    /// Tool name pattern or arbitrary text pattern. `nil` = match everything.
    public var matcher: String?
    /// Hook commands to execute when this matcher fires.
    public var hooks: [HookCommand]

    public init(matcher: String? = nil, hooks: [HookCommand]) {
        self.matcher = matcher
        self.hooks = hooks
    }
}

// MARK: - HookConfig

/// Top-level hooks configuration — deserialized from the `hooks` key in settings.json.
///
/// The JSON shape is:
/// ```json
/// {
///   "hooks": {
///     "PreToolUse": [{ "matcher": "Bash", "hooks": [{"type":"command","command":"..."}] }],
///     "Notification": [{ "hooks": [{"type":"command","command":"..."}] }]
///   }
/// }
/// ```
public struct HookConfig: Codable, Sendable {
    /// Map from event type string to matchers.
    public var hooks: [String: [HookMatcher]]

    public init(hooks: [String: [HookMatcher]] = [:]) {
        self.hooks = hooks
    }

    /// Returns matchers registered for the given event type.
    public func matchers(for event: HookEventType) -> [HookMatcher] {
        hooks[event.rawValue] ?? []
    }

    /// Returns true if any hooks are configured for the given event type.
    public func hasHooks(for event: HookEventType) -> Bool {
        !(hooks[event.rawValue] ?? []).isEmpty
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        var map: [String: [HookMatcher]] = [:]
        for key in container.allKeys {
            map[key.stringValue] = try container.decode([HookMatcher].self, forKey: key)
        }
        self.hooks = map
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        for (key, matchers) in hooks {
            try container.encode(matchers, forKey: AnyCodingKey(key))
        }
    }
}

// MARK: - AnyCodingKey (local alias — same helper used in SettingsSchema)

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
