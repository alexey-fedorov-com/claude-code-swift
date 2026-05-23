/// Keybinding — Codable schema for user-defined keyboard shortcuts.
///
/// Mirrors `~/.claude/keybindings.json` format from the TypeScript source.
/// See `src/utils/keybindings.ts`.

import Foundation

// MARK: - Keybinding

/// A single mapping from a key combination to a named action.
public struct Keybinding: Codable, Equatable, Hashable, Sendable {
    /// Key combination string, e.g. `"ctrl+s"`, `"cmd+shift+enter"`, `"ctrl+alt+k"`.
    public let key: String
    /// Action identifier, e.g. `"submit"`, `"clear"`, `"vim.toggle"`.
    public let action: String
    /// Optional human-readable description.
    public let description: String?
    /// If true, the binding fires only when the input field is empty.
    public let whenEmpty: Bool?

    public init(
        key: String,
        action: String,
        description: String? = nil,
        whenEmpty: Bool? = nil
    ) {
        self.key = key
        self.action = action
        self.description = description
        self.whenEmpty = whenEmpty
    }
}

// MARK: - ValidationWarning

/// A non-fatal issue found when validating a keybinding set.
public struct ValidationWarning: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Two bindings share the same key combo; the later one wins.
        case conflict(existing: Keybinding, incoming: Keybinding)
        /// The key combo is in the system-reserved set and cannot be rebound.
        case reservedShortcut(key: String)
        /// The action name is unrecognised.
        case unknownAction(action: String)
    }
    public let kind: Kind
    public let message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }
}
