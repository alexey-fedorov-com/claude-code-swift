/// SettingsLoader — multi-source settings loader.
///
/// Mirrors the loading / merging logic in `src/utils/settings/settings.ts`.
/// Sources load in order: user → project → local → flag → policy.
/// Later sources win for scalar fields; arrays are concatenated (allow/deny/ask lists).

import Foundation
import SwiftCodeCore

// MARK: - Setting Sources

/// All possible sources where settings can originate, in load order.
/// Mirrors `SETTING_SOURCES` from `src/utils/settings/constants.ts`.
public enum SettingSource: String, CaseIterable, Sendable {
    case userSettings
    case projectSettings
    case localSettings
    case flagSettings
    case policySettings

    public var displayName: String {
        switch self {
        case .userSettings:    return "user"
        case .projectSettings: return "project"
        case .localSettings:   return "project, gitignored"
        case .flagSettings:    return "cli flag"
        case .policySettings:  return "managed"
        }
    }
}

// MARK: - Tagged Setting

/// A settings value annotated with its origin source.
public struct TaggedSetting<T: Sendable>: Sendable {
    public let value: T
    public let source: SettingSource

    public init(value: T, source: SettingSource) {
        self.value = value
        self.source = source
    }
}

// MARK: - Merged Settings

/// The fully-merged view across all sources, with origin information preserved.
public struct MergedSettings: Sendable {
    public var model: TaggedSetting<String>?
    public var theme: TaggedSetting<String>?
    public var apiKeyHelper: TaggedSetting<String>?
    public var cleanupPeriodDays: TaggedSetting<Int>?
    public var disableSkillShellExecution: TaggedSetting<Bool>?
    public var skipDangerousModePermissionPrompt: TaggedSetting<Bool>?
    public var verbose: TaggedSetting<Bool>?
    public var showThinkingSummaries: TaggedSetting<Bool>?
    public var autoCompactEnabled: TaggedSetting<Bool>?
    public var preferredNotifChannel: TaggedSetting<String>?
    public var includeCoAuthoredBy: TaggedSetting<Bool>?

    /// Merged env — later source wins per key.
    public var env: [String: TaggedSetting<String>]

    /// Merged permissions — defaultMode from latest source; allow/deny/ask lists concatenated.
    public var permissionsDefaultMode: TaggedSetting<String>?
    public var allowRules: [TaggedSetting<String>]
    public var denyRules: [TaggedSetting<String>]
    public var askRules: [TaggedSetting<String>]
    public var additionalDirectories: [TaggedSetting<String>]

    /// Validation errors encountered during load (settings with errors are excluded).
    public var validationErrors: [(source: SettingSource, error: Error)]

    public init() {
        env = [:]
        allowRules = []
        denyRules = []
        askRules = []
        additionalDirectories = []
        validationErrors = []
    }
}

// MARK: - Settings Loader

public struct SettingsLoader {

    // MARK: - Load from file

    /// Load and parse a `SettingsSchema` from a JSON file.
    /// Returns `nil` if the file does not exist.
    /// Throws on JSON parse failures.
    public static func loadFile(at url: URL) throws -> SettingsSchema? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SettingsSchema.self, from: data)
    }

    /// Save a `SettingsSchema` to a JSON file.
    public static func saveFile(_ settings: SettingsSchema, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        // Ensure parent directory exists
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Multi-source load

    /// Load settings from all standard sources and merge them.
    ///
    /// - Parameters:
    ///   - projectDirectory: The current project/working directory.
    ///   - flagSettingsURL: Path passed via `--settings` CLI flag, if any.
    public static func loadMerged(
        projectDirectory: URL? = nil,
        flagSettingsURL: URL? = nil
    ) -> MergedSettings {
        var sources: [(SettingSource, URL)] = [
            (.userSettings, ConfigPaths.userSettingsPath()),
        ]
        if let proj = projectDirectory {
            sources.append((.projectSettings, ConfigPaths.projectSettingsPath(for: proj)))
            sources.append((.localSettings, ConfigPaths.localProjectSettingsPath(for: proj)))
        }
        if let flagURL = flagSettingsURL {
            sources.append((.flagSettings, flagURL))
        }
        sources.append((.policySettings, ConfigPaths.policySettingsPath()))

        var merged = MergedSettings()
        for (source, url) in sources {
            guard let schema = try? loadFile(at: url) else { continue }
            // Validate; on failure record error and skip this source's fields
            do {
                try schema.validate()
            } catch {
                merged.validationErrors.append((source: source, error: error))
                continue
            }
            applySchema(schema, source: source, into: &merged)
        }
        return merged
    }

    // MARK: - Merge application

    private static func applySchema(
        _ schema: SettingsSchema,
        source: SettingSource,
        into merged: inout MergedSettings
    ) {
        if let v = schema.model { merged.model = .init(value: v, source: source) }
        if let v = schema.theme { merged.theme = .init(value: v, source: source) }
        if let v = schema.apiKeyHelper { merged.apiKeyHelper = .init(value: v, source: source) }
        if let v = schema.cleanupPeriodDays { merged.cleanupPeriodDays = .init(value: v, source: source) }
        if let v = schema.disableSkillShellExecution { merged.disableSkillShellExecution = .init(value: v, source: source) }
        if let v = schema.skipDangerousModePermissionPrompt { merged.skipDangerousModePermissionPrompt = .init(value: v, source: source) }
        if let v = schema.verbose { merged.verbose = .init(value: v, source: source) }
        if let v = schema.showThinkingSummaries { merged.showThinkingSummaries = .init(value: v, source: source) }
        if let v = schema.autoCompactEnabled { merged.autoCompactEnabled = .init(value: v, source: source) }
        if let v = schema.preferredNotifChannel { merged.preferredNotifChannel = .init(value: v, source: source) }
        if let v = schema.includeCoAuthoredBy { merged.includeCoAuthoredBy = .init(value: v, source: source) }

        // env: later source wins per key
        if let envMap = schema.env {
            for (key, value) in envMap {
                merged.env[key] = .init(value: value, source: source)
            }
        }

        // permissions
        if let perms = schema.permissions {
            if let mode = perms.defaultMode {
                merged.permissionsDefaultMode = .init(value: mode, source: source)
            }
            for rule in perms.allow ?? [] {
                merged.allowRules.append(.init(value: rule, source: source))
            }
            for rule in perms.deny ?? [] {
                merged.denyRules.append(.init(value: rule, source: source))
            }
            for rule in perms.ask ?? [] {
                merged.askRules.append(.init(value: rule, source: source))
            }
            for dir in perms.additionalDirectories ?? [] {
                merged.additionalDirectories.append(.init(value: dir, source: source))
            }
        }
    }
}
