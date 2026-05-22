/// Permission update types and application logic.
///
/// Mirrors the TypeScript reference at:
/// - src/types/permissions.ts (PermissionUpdate)
/// - src/utils/permissions/PermissionUpdate.ts
///
/// Applies rule additions/removals to a settings-like structure.
/// Uses simple String-array representation for allow/deny/ask rule lists,
/// matching the shape of SwiftCodeSettings.SettingsSchema permission fields.

import Foundation

// MARK: - Permission Update

/// Where a permission update should be persisted.
public typealias UpdateDestination = PermissionUpdateDestination

/// A structured permission update operation.
public enum PermissionUpdate: Sendable {
    /// Add rules for a given behavior to a destination.
    case addRules(
        destination: UpdateDestination,
        rules: [PermissionRuleValue],
        behavior: PermissionBehavior
    )
    /// Remove rules matching a given behavior from a destination.
    case removeRules(
        destination: UpdateDestination,
        rules: [PermissionRuleValue],
        behavior: PermissionBehavior
    )
    /// Replace all rules for a behavior at a destination.
    case replaceRules(
        destination: UpdateDestination,
        rules: [PermissionRuleValue],
        behavior: PermissionBehavior
    )
    /// Change the permission mode at a destination.
    case setMode(
        destination: UpdateDestination,
        mode: ExternalPermissionMode
    )
    /// Add working directories to the permission scope.
    case addDirectories(
        destination: UpdateDestination,
        directories: [String]
    )
    /// Remove working directories from the permission scope.
    case removeDirectories(
        destination: UpdateDestination,
        directories: [String]
    )
}

// MARK: - Flat Rule Lists

/// A flat representation of permission rule lists, compatible with settings JSON.
public struct PermissionRuleLists: Sendable {
    public var allow: [String]
    public var deny: [String]
    public var ask: [String]

    public init(allow: [String] = [], deny: [String] = [], ask: [String] = []) {
        self.allow = allow
        self.deny = deny
        self.ask = ask
    }
}

// MARK: - Apply Updates

/// Applies a sequence of `PermissionUpdate` operations to flat rule lists.
///
/// This is a pure function — it returns new lists without mutating the input.
/// Callers are responsible for persisting the result to the appropriate
/// settings destination.
///
/// - Parameters:
///   - lists: Current allow/deny/ask rule lists (as raw strings).
///   - updates: The updates to apply.
/// - Returns: Updated rule lists after applying all updates in order.
public func applyPermissionUpdates(
    to lists: PermissionRuleLists,
    updates: [PermissionUpdate]
) -> PermissionRuleLists {
    var result = lists

    for update in updates {
        switch update {
        case .addRules(_, let rules, let behavior):
            let newStrings = rules.map { permissionRuleValueToString($0) }
            switch behavior {
            case .allow:
                result.allow = addUnique(to: result.allow, values: newStrings)
            case .deny:
                result.deny = addUnique(to: result.deny, values: newStrings)
            case .ask:
                result.ask = addUnique(to: result.ask, values: newStrings)
            }

        case .removeRules(_, let rules, let behavior):
            let toRemove = Set(rules.map { permissionRuleValueToString($0) })
            switch behavior {
            case .allow:
                result.allow = result.allow.filter { !toRemove.contains($0) }
            case .deny:
                result.deny = result.deny.filter { !toRemove.contains($0) }
            case .ask:
                result.ask = result.ask.filter { !toRemove.contains($0) }
            }

        case .replaceRules(_, let rules, let behavior):
            let newStrings = rules.map { permissionRuleValueToString($0) }
            switch behavior {
            case .allow:
                result.allow = newStrings
            case .deny:
                result.deny = newStrings
            case .ask:
                result.ask = newStrings
            }

        case .setMode:
            // Mode changes are applied to a higher-level settings object;
            // they don't affect rule lists directly.
            break

        case .addDirectories:
            // Directory additions are applied at the agent loop level (Task 12).
            // No-op here.
            break

        case .removeDirectories:
            // Directory removals are applied at the agent loop level (Task 12).
            // No-op here.
            break
        }
    }

    return result
}

// MARK: - Helpers

private func addUnique(to existing: [String], values: [String]) -> [String] {
    var result = existing
    let existingSet = Set(existing)
    for v in values where !existingSet.contains(v) {
        result.append(v)
    }
    return result
}

// MARK: - Rule Extraction

/// Extracts matching rules for a given tool name and behavior from a flat rule list.
///
/// Returns a dictionary keyed by `ruleContent` (or "" for tool-wide rules).
public func extractRulesForTool(
    toolName: String,
    from rules: [String],
    source: PermissionRuleSource,
    behavior: PermissionBehavior
) -> [String: PermissionRule] {
    var result: [String: PermissionRule] = [:]
    for raw in rules {
        let ruleValue = permissionRuleValueFromString(raw)
        if ruleValue.toolName == toolName {
            let key = ruleValue.ruleContent ?? ""
            result[key] = PermissionRule(
                source: source,
                ruleBehavior: behavior,
                ruleValue: ruleValue
            )
        }
    }
    return result
}
