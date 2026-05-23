/// PluginManagerTests — tests for PluginManager and PluginBin.

import Testing
import Foundation
@testable import SwiftCodePlugins

// MARK: - PluginBin Tests

@Suite("PluginBin")
struct PluginBinTests {

    @Test("2.1.91 backport: augments PATH with enabled plugin bin dirs that exist")
    func augmentsPATH() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("plugin-bin-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create a fake plugin with a bin/ directory
        let pluginDir = tmpDir.appendingPathComponent("test-plugin", isDirectory: true)
        let binDir = pluginDir.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)

        let manifest = PluginManifest(name: "test-plugin", version: "1.0.0", bin: ["cmd": "bin/cmd"])
        let plugin = Plugin(manifest: manifest, directory: pluginDir, isEnabled: true)

        let result = PluginBin.augmentPATH(currentPATH: "/usr/bin:/usr/local/bin", plugins: [plugin])
        #expect(result.hasPrefix(binDir.path))
        #expect(result.contains("/usr/bin"))
    }

    @Test("does not add non-existent bin directories")
    func skipsNonExistentBin() {
        let pluginDir = URL(fileURLWithPath: "/tmp/nonexistent-plugin-dir")
        let manifest = PluginManifest(name: "ghost-plugin", version: "1.0.0", bin: ["cmd": "bin/cmd"])
        let plugin = Plugin(manifest: manifest, directory: pluginDir, isEnabled: true)

        let result = PluginBin.augmentPATH(currentPATH: "/usr/bin", plugins: [plugin])
        #expect(result == "/usr/bin")
    }

    @Test("skips disabled plugins")
    func skipsDisabledPlugins() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("plugin-disabled-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let pluginDir = tmpDir.appendingPathComponent("disabled-plugin", isDirectory: true)
        let binDir = pluginDir.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)

        let manifest = PluginManifest(name: "disabled-plugin", version: "1.0.0", bin: ["cmd": "bin/cmd"])
        let plugin = Plugin(manifest: manifest, directory: pluginDir, isEnabled: false)

        let result = PluginBin.augmentPATH(currentPATH: "/usr/bin", plugins: [plugin])
        #expect(result == "/usr/bin")
        #expect(!result.contains(binDir.path))
    }

    @Test("returns original PATH when no enabled plugins with bin dirs")
    func returnsOriginalPATH() {
        let result = PluginBin.augmentPATH(currentPATH: "/usr/bin:/usr/local/bin", plugins: [])
        #expect(result == "/usr/bin:/usr/local/bin")
    }

    @Test("handles empty PATH gracefully")
    func handlesEmptyPATH() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("plugin-empty-path-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let pluginDir = tmpDir.appendingPathComponent("plugin", isDirectory: true)
        let binDir = pluginDir.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)

        let manifest = PluginManifest(name: "plugin", version: "1.0.0", bin: ["cmd": "bin/cmd"])
        let plugin = Plugin(manifest: manifest, directory: pluginDir, isEnabled: true)

        let result = PluginBin.augmentPATH(currentPATH: "", plugins: [plugin])
        #expect(result == binDir.path)
    }
}

// MARK: - PluginManager Tests

@Suite("PluginManager")
struct PluginManagerTests {

    @Test("returns empty list when plugins directory doesn't exist")
    func emptyWhenNoDirExists() async throws {
        let fakeDir = URL(fileURLWithPath: "/tmp/nonexistent-plugins-\(UUID().uuidString)")
        let runner = MockProcessRunner()
        let manager = PluginManager(pluginsDirectory: fakeDir, processRunner: runner)
        let plugins = try await manager.installed()
        #expect(plugins.isEmpty)
    }

    @Test("installs plugin from local directory")
    func installsFromLocalDir() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("plugin-install-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let sourceDir = tmpDir.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        // Write a valid manifest
        let manifest = #"{"name":"install-test","version":"1.0.0","description":"Test plugin"}"#
        let manifestURL = sourceDir.appendingPathComponent("package.json")
        try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)

        let pluginsDir = tmpDir.appendingPathComponent("plugins", isDirectory: true)
        let runner = MockProcessRunner()
        let manager = PluginManager(pluginsDirectory: pluginsDir, processRunner: runner)

        let plugin = try await manager.install(from: sourceDir)
        #expect(plugin.name == "install-test")
        #expect(plugin.version == "1.0.0")
    }

    @Test("throws notFound when uninstalling non-existent plugin")
    func throwsNotFoundOnUninstall() async throws {
        let fakeDir = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString)")
        let runner = MockProcessRunner()
        let manager = PluginManager(pluginsDirectory: fakeDir, processRunner: runner)

        var didThrow = false
        do {
            try await manager.uninstall(name: "ghost-plugin")
        } catch PluginManagerError.notFound {
            didThrow = true
        }
        #expect(didThrow)
    }

    @Test("validates manifest before installing")
    func validatesManifest() throws {
        let runner = MockProcessRunner()
        let manager = PluginManager(
            pluginsDirectory: URL(fileURLWithPath: "/tmp"),
            processRunner: runner
        )

        let valid = PluginManifest(name: "good-plugin", version: "1.0.0")
        try manager.validate(valid)

        let invalid = PluginManifest(name: "", version: "1.0.0")
        #expect(throws: PluginManifestError.emptyName) {
            try manager.validate(invalid)
        }
    }
}

// MARK: - MockProcessRunner

final class MockProcessRunner: ProcessRunnerProtocol, @unchecked Sendable {
    func run(
        executable: String,
        arguments: [String],
        workingDirectory: URL?
    ) async throws -> ProcessResultProtocol {
        MockProcessResult(exitCode: 0, stdout: "", stderr: "")
    }
}

struct MockProcessResult: ProcessResultProtocol {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
