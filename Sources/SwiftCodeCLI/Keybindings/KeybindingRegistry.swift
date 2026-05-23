/// KeybindingRegistry — load, validate, and look up keybindings.
///
/// Mirrors `src/utils/keybindings.ts` from the TypeScript source.
/// Config file: `~/.claude/keybindings.json` (array of Keybinding objects).

import Foundation

// MARK: - Known actions

private let knownActions: Set<String> = [
    "submit",
    "newline",
    "clear",
    "cancel",
    "abort",
    "history.prev",
    "history.next",
    "completion.accept",
    "completion.next",
    "completion.prev",
    "vim.toggle",
    "vim.escape",
    "voice.start",
    "voice.stop",
]

// MARK: - KeybindingRegistry

public enum KeybindingRegistry {

    // MARK: - Load

    /// Load keybindings from the given JSON file.
    ///
    /// If the file does not exist an empty array is returned (not an error).
    /// Throws `DecodingError` if the file exists but is malformed.
    public static func load(from path: URL) throws -> [Keybinding] {
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode([Keybinding].self, from: data)
    }

    /// Load from the default keybindings path (`~/.claude/keybindings.json`).
    public static func loadDefault() throws -> [Keybinding] {
        try load(from: defaultPath())
    }

    // MARK: - Save

    /// Persist keybindings to the given path (pretty-printed JSON).
    public static func save(_ bindings: [Keybinding], to path: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bindings)
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: path, options: .atomic)
    }

    // MARK: - Lookup

    /// Return the first binding whose key matches `combo` (case-insensitive).
    public static func action(for combo: String, in bindings: [Keybinding]) -> String? {
        bindings.first { $0.key.lowercased() == combo.lowercased() }?.action
    }

    // MARK: - Validation

    /// Validate a binding set and return warnings for conflicts / reserved keys / unknown actions.
    public static func validate(_ bindings: [Keybinding]) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        var seen: [String: Keybinding] = [:]

        for binding in bindings {
            let key = binding.key.lowercased()

            // Reserved shortcut check
            if ReservedShortcuts.isReserved(key) {
                warnings.append(ValidationWarning(
                    kind: .reservedShortcut(key: key),
                    message: "'\(key)' is a reserved system shortcut and cannot be rebound."
                ))
            }

            // Conflict check
            if let existing = seen[key] {
                warnings.append(ValidationWarning(
                    kind: .conflict(existing: existing, incoming: binding),
                    message: "Key '\(key)' is bound to both '\(existing.action)' and '\(binding.action)'. The later binding wins."
                ))
            }
            seen[key] = binding

            // Unknown action check
            if !knownActions.contains(binding.action) {
                warnings.append(ValidationWarning(
                    kind: .unknownAction(action: binding.action),
                    message: "Action '\(binding.action)' is not a recognised keybinding action."
                ))
            }
        }

        return warnings
    }

    // MARK: - Paths

    /// Default keybindings file path: `~/.claude/keybindings.json`.
    public static func defaultPath() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("keybindings.json")
    }
}
