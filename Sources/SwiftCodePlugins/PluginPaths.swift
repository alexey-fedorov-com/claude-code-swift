/// PluginPaths — path resolution for the plugin directory tree.
///
/// Mirrors .reference/src/utils/plugins/pluginDirectories.ts

import Foundation
import SwiftCodeCore

// MARK: - PluginPaths

public enum PluginPaths {
    // MARK: - Root directories

    /// Root plugins directory: `~/.claude/plugins/`
    public static func directory() -> URL {
        ConfigPaths.configHomeDirectory()
            .appendingPathComponent("plugins", isDirectory: true)
    }

    /// Marketplace cache directory: `~/.claude/plugins/marketplaces/`
    public static func marketplacesDirectory() -> URL {
        directory().appendingPathComponent("marketplaces", isDirectory: true)
    }

    /// Known marketplaces config file: `~/.claude/plugins/known_marketplaces.json`
    public static func knownMarketplacesFile() -> URL {
        directory().appendingPathComponent("known_marketplaces.json")
    }

    // MARK: - Per-plugin directory

    /// Directory for an installed plugin: `~/.claude/plugins/<name>/`
    public static func pluginDirectory(name: String) -> URL {
        directory().appendingPathComponent(name, isDirectory: true)
    }

    /// Plugin manifest: `~/.claude/plugins/<name>/package.json`
    public static func manifestPath(for pluginName: String) -> URL {
        pluginDirectory(name: pluginName).appendingPathComponent("package.json")
    }

    /// Plugin bin directory: `~/.claude/plugins/<name>/bin/`
    public static func binDirectory(for pluginName: String) -> URL {
        pluginDirectory(name: pluginName).appendingPathComponent("bin", isDirectory: true)
    }

    // MARK: - Skills

    /// User skills directory: `~/.claude/skills/`
    public static func skillsDirectory() -> URL {
        ConfigPaths.configHomeDirectory()
            .appendingPathComponent("skills", isDirectory: true)
    }

    /// Project-local skills directory relative to a project root.
    public static func projectSkillsDirectory(for projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
    }

    // MARK: - Helpers

    /// Creates a directory if it doesn't already exist.
    public static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}
