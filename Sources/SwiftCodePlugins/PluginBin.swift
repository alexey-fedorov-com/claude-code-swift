/// PluginBin — PATH injection for plugin executables.
///
/// 2.1.91 backport: "Plugin `bin/` executables — plugins can ship executables
/// under `bin/` that are prepended to PATH for Bash tool."
///
/// Mirrors .reference/src/utils/plugins/plugin.ts (bin/ path logic) and
/// .reference/src/utils/subprocessEnv.ts (PATH augmentation).

import Foundation

// MARK: - PluginBin

public enum PluginBin {
    /// Returns a new PATH string with plugin bin/ directories prepended.
    ///
    /// Only includes bin directories from enabled plugins that actually exist
    /// on disk (avoids polluting PATH with phantom directories).
    ///
    /// - Parameters:
    ///   - currentPATH: The current value of the `PATH` environment variable.
    ///   - plugins: Installed plugins to scan for `bin/` directories.
    /// - Returns: Modified PATH string with plugin bin dirs at the front.
    public static func augmentPATH(currentPATH: String, plugins: [Plugin]) -> String {
        var binDirs: [String] = []

        for plugin in plugins where plugin.isEnabled {
            let binDir = plugin.binDirectory
            // Only prepend if the directory actually exists
            if FileManager.default.fileExists(atPath: binDir.path) {
                binDirs.append(binDir.path)
            }
        }

        if binDirs.isEmpty {
            return currentPATH
        }

        let prefix = binDirs.joined(separator: ":")
        if currentPATH.isEmpty {
            return prefix
        }
        return "\(prefix):\(currentPATH)"
    }

    /// Builds a full environment dictionary with the augmented PATH.
    ///
    /// - Parameters:
    ///   - env: Base environment (defaults to the current process environment).
    ///   - plugins: Plugins whose `bin/` dirs should be prepended to PATH.
    /// - Returns: New environment dictionary with updated PATH.
    public static func buildEnvironment(
        base env: [String: String] = ProcessInfo.processInfo.environment,
        plugins: [Plugin]
    ) -> [String: String] {
        var result = env
        let currentPATH = env["PATH"] ?? ""
        result["PATH"] = augmentPATH(currentPATH: currentPATH, plugins: plugins)
        return result
    }
}
