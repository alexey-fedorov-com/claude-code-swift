/// Enterprise allow/deny policy filter for MCP tools and servers (stub).
///
/// In the TypeScript reference, policy filtering applies allow/deny lists
/// from enterprise settings to restrict which MCP servers and tools are available.
/// This is a minimal stub implementing the core filter logic.

import Foundation

// MARK: - PolicyRule

public struct PolicyRule: Codable, Sendable {
    public enum Action: String, Codable, Sendable {
        case allow
        case deny
    }

    /// "server:toolname", "server:*", or "*:*"
    public let pattern: String
    public let action: Action

    public init(pattern: String, action: Action) {
        self.pattern = pattern
        self.action = action
    }
}

// MARK: - PolicyFilter

/// Filters MCP server/tool access by an allow/deny list.
///
/// Rules are evaluated in order; first match wins.
/// If no rule matches, the default is `.allow`.
public struct PolicyFilter: Sendable {

    private let rules: [PolicyRule]
    private let defaultAction: PolicyRule.Action

    public init(rules: [PolicyRule] = [], default defaultAction: PolicyRule.Action = .allow) {
        self.rules = rules
        self.defaultAction = defaultAction
    }

    /// Check if a specific server+tool combination is allowed.
    public func isAllowed(server: String, tool: String) -> Bool {
        let target = "\(server):\(tool)"
        for rule in rules {
            if matches(pattern: rule.pattern, target: target) {
                return rule.action == .allow
            }
        }
        return defaultAction == .allow
    }

    /// Check if a server is allowed (any tool).
    public func isServerAllowed(_ server: String) -> Bool {
        isAllowed(server: server, tool: "*")
    }

    /// Filter a list of tools, returning only allowed ones.
    public func filteredTools(
        server: String,
        tools: [MCPTool]
    ) -> [MCPTool] {
        tools.filter { isAllowed(server: server, tool: $0.name) }
    }

    // MARK: Pattern matching

    private func matches(pattern: String, target: String) -> Bool {
        // Exact match
        if pattern == target { return true }
        // Wildcard patterns: "server:*" or "*:*"
        if pattern.hasSuffix(":*") {
            let prefix = String(pattern.dropLast(2))
            if prefix == "*" { return true }
            return target.hasPrefix(prefix + ":")
        }
        return false
    }
}
