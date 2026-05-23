/// PluginManager — load/install/enable/disable plugins.
///
/// Mirrors .reference/src/utils/plugins/installedPluginsManager.ts and related files.
/// Each plugin lives at `~/.claude/plugins/<name>/` with a `package.json` manifest.

import Foundation
import SwiftCodeCore

// MARK: - PluginManagerError

public enum PluginManagerError: Error, LocalizedError {
    case notFound(String)
    case alreadyInstalled(String)
    case installFailed(String, Error)
    case manifestLoadFailed(URL, Error)
    case isManaged(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let n):            return "Plugin '\(n)' is not installed"
        case .alreadyInstalled(let n):    return "Plugin '\(n)' is already installed"
        case .installFailed(let n, let e):return "Failed to install plugin '\(n)': \(e.localizedDescription)"
        case .manifestLoadFailed(let u, let e): return "Failed to load manifest at \(u.path): \(e.localizedDescription)"
        case .isManaged(let n):           return "Plugin '\(n)' is managed and cannot be modified"
        }
    }
}

// MARK: - PluginManager

/// Actor that manages the installed plugin lifecycle.
public actor PluginManager {
    private let pluginsDirectory: URL
    private let processRunner: ProcessRunnerProtocol

    public init(
        pluginsDirectory: URL = PluginPaths.directory(),
        processRunner: ProcessRunnerProtocol
    ) {
        self.pluginsDirectory = pluginsDirectory
        self.processRunner = processRunner
    }

    // MARK: - List

    /// Returns all installed plugins, regardless of enabled state.
    public func installed() async throws -> [Plugin] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: pluginsDirectory.path) else { return [] }

        let entries = try fm.contentsOfDirectory(
            at: pluginsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var plugins: [Plugin] = []
        for entry in entries {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: entry.path, isDirectory: &isDir)
            guard isDir.boolValue else { continue }

            if let plugin = try? loadPlugin(from: entry) {
                plugins.append(plugin)
            }
        }

        return plugins.sorted { $0.name < $1.name }
    }

    // MARK: - Install

    /// Installs a plugin from a source URL (git clone or local copy).
    /// Throws `.alreadyInstalled` if a plugin with the same name is present.
    public func install(from source: URL) async throws -> Plugin {
        // For git URLs: clone. For local paths: copy.
        let name = source.deletingPathExtension().lastPathComponent

        let targetDir = pluginsDirectory.appendingPathComponent(name, isDirectory: true)
        let fm = FileManager.default

        if fm.fileExists(atPath: targetDir.path) {
            throw PluginManagerError.alreadyInstalled(name)
        }

        do {
            try PluginPaths.ensureDirectory(targetDir)

            if source.isFileURL && fm.fileExists(atPath: source.path) {
                // Local directory install: copy contents
                for item in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
                    let dest = targetDir.appendingPathComponent(item.lastPathComponent)
                    try fm.copyItem(at: item, to: dest)
                }
            } else {
                // Git clone
                _ = try await processRunner.run(
                    executable: "git",
                    arguments: ["clone", "--depth", "1", source.absoluteString, targetDir.path],
                    workingDirectory: nil
                )
            }
        } catch {
            // Clean up on failure
            try? fm.removeItem(at: targetDir)
            throw PluginManagerError.installFailed(name, error)
        }

        guard let plugin = try? loadPlugin(from: targetDir) else {
            try? fm.removeItem(at: targetDir)
            let manifestURL = PluginPaths.manifestPath(for: name)
            throw PluginManagerError.manifestLoadFailed(manifestURL, PluginManifestError.missingManifestFile(manifestURL))
        }

        return plugin
    }

    // MARK: - Uninstall

    public func uninstall(name: String) async throws {
        let plugin = try getPlugin(name: name)
        if plugin.isManaged {
            throw PluginManagerError.isManaged(name)
        }
        try FileManager.default.removeItem(at: plugin.directory)
    }

    // MARK: - Enable / Disable

    public func enable(name: String) async throws {
        var plugin = try getPlugin(name: name)
        plugin.isEnabled = true
        try saveState(for: plugin)
    }

    public func disable(name: String) async throws {
        var plugin = try getPlugin(name: name)
        plugin.isEnabled = false
        try saveState(for: plugin)
    }

    // MARK: - Validate

    public nonisolated func validate(_ manifest: PluginManifest) throws {
        try manifest.validate()
    }

    // MARK: - Update

    public func update(name: String) async throws -> Plugin {
        let plugin = try getPlugin(name: name)
        if plugin.isManaged {
            throw PluginManagerError.isManaged(name)
        }

        _ = try await processRunner.run(
            executable: "git",
            arguments: ["pull", "--ff-only"],
            workingDirectory: plugin.directory
        )

        return try loadPlugin(from: plugin.directory)
    }

    // MARK: - Private

    private func getPlugin(name: String) throws -> Plugin {
        let dir = pluginsDirectory.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dir.path),
              let plugin = try? loadPlugin(from: dir) else {
            throw PluginManagerError.notFound(name)
        }
        return plugin
    }

    private func loadPlugin(from directory: URL) throws -> Plugin {
        let manifestURL = directory.appendingPathComponent("package.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PluginManifestError.missingManifestFile(manifestURL)
        }

        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            throw PluginManagerError.manifestLoadFailed(manifestURL, error)
        }

        let manifest: PluginManifest
        do {
            manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
        } catch {
            throw PluginManifestError.decodingFailed(error)
        }

        // Load enabled state from state file
        let stateURL = directory.appendingPathComponent(".plugin-state.json")
        var isEnabled = true
        if let stateData = try? Data(contentsOf: stateURL),
           let state = try? JSONDecoder().decode(PluginState.self, from: stateData) {
            isEnabled = state.enabled
        }

        return Plugin(manifest: manifest, directory: directory, isEnabled: isEnabled)
    }

    private func saveState(for plugin: Plugin) throws {
        let stateURL = plugin.directory.appendingPathComponent(".plugin-state.json")
        let state = PluginState(enabled: plugin.isEnabled)
        let data = try JSONEncoder().encode(state)
        try data.write(to: stateURL, options: .atomic)
    }
}
