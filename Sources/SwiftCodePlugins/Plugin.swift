/// Plugin — an installed plugin instance.
///
/// Mirrors .reference/src/utils/plugins/ plugin model.

import Foundation

// MARK: - Plugin

public struct Plugin: Sendable, Equatable {
    /// Plugin name (from manifest).
    public let name: String
    /// Plugin version (from manifest).
    public let version: String
    /// Human-readable description.
    public let description: String?
    /// The directory where the plugin is installed.
    public let directory: URL
    /// The parsed manifest.
    public let manifest: PluginManifest
    /// Whether the plugin is currently enabled.
    public var isEnabled: Bool
    /// Whether the plugin is managed externally.
    public var isManaged: Bool

    public init(
        manifest: PluginManifest,
        directory: URL,
        isEnabled: Bool = true
    ) {
        self.name = manifest.name
        self.version = manifest.version
        self.description = manifest.description
        self.directory = directory
        self.manifest = manifest
        self.isEnabled = isEnabled
        self.isManaged = manifest.isManaged ?? false
    }

    // MARK: - Equatable

    public static func == (lhs: Plugin, rhs: Plugin) -> Bool {
        lhs.name == rhs.name && lhs.directory == rhs.directory
    }

    // MARK: - Paths

    /// Path to the plugin's `bin/` directory.
    public var binDirectory: URL {
        directory.appendingPathComponent("bin", isDirectory: true)
    }

    /// Absolute paths to all executables in `bin/`.
    public var binPaths: [URL] {
        guard let bin = manifest.bin else { return [] }
        return bin.values.map { relativePath in
            directory.appendingPathComponent(relativePath)
        }
    }
}

// MARK: - PluginState

/// Minimal persisted state for each plugin (enabled/disabled).
public struct PluginState: Codable, Sendable {
    public var enabled: Bool

    public init(enabled: Bool = true) {
        self.enabled = enabled
    }
}
