/// ConfigPaths — config home path resolver.
///
/// Mirrors `getClaudeConfigHomeDir()` from `src/utils/envUtils.ts`.
/// Config dir intentionally stays at `~/.claude/` (not `~/.swiftcode/`)
/// to preserve user data and remain compatible with existing setups.

import Foundation

public enum ConfigPaths {
    // MARK: - Config home

    /// Returns the root config directory.
    ///
    /// Checks `$CLAUDE_CONFIG_DIR` first; falls back to `~/.claude`.
    public static func configHomeDirectory() -> URL {
        if let envOverride = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"],
           !envOverride.isEmpty {
            return URL(fileURLWithPath: envOverride, isDirectory: true)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude", isDirectory: true)
    }

    // MARK: - Global files

    /// `~/.claude.json` — the global config/state file.
    public static func globalConfigPath() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude.json")
    }

    /// `~/.claude/settings.json` — the user-level (global) settings file.
    public static func userSettingsPath() -> URL {
        configHomeDirectory().appendingPathComponent("settings.json")
    }

    /// `~/.claude/settings.local.json` — machine-local user settings (gitignored).
    public static func userLocalSettingsPath() -> URL {
        configHomeDirectory().appendingPathComponent("settings.local.json")
    }

    // MARK: - Per-project files

    /// `.claude/settings.json` inside `projectDirectory` — shared project settings.
    public static func projectSettingsPath(for projectDirectory: URL) -> URL {
        projectDirectory
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    /// `.claude/settings.local.json` inside `projectDirectory` — gitignored local settings.
    public static func localProjectSettingsPath(for projectDirectory: URL) -> URL {
        projectDirectory
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.local.json")
    }

    // MARK: - Enterprise / MDM

    /// Platform-specific managed settings file (enterprise policy).
    /// On macOS: `/Library/Application Support/ClaudeCode/managed-settings.json`.
    public static func policySettingsPath() -> URL {
        URL(fileURLWithPath: "/Library/Application Support/ClaudeCode/managed-settings.json")
    }

    /// MDM preferences plist location (macOS).
    public static func mdmSettingsPath() -> URL {
        URL(fileURLWithPath: "/Library/Managed Preferences/com.anthropic.claudecode.plist")
    }
}
