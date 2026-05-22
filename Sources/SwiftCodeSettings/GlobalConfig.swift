/// GlobalConfig — global config file at ~/.claude.json.
///
/// Mirrors `GlobalConfig` and `getGlobalConfig()` from `src/utils/config.ts`.
/// This file stores per-user state: onboarding, tips, numStartups, per-project
/// configs, oauth info, etc.
///
/// Unknown fields are preserved via `extraFields` to ensure forward/backward compat.

import Foundation
import SwiftCodeCore

// MARK: - GlobalConfig

public struct GlobalConfig: Codable, Sendable {

    // MARK: Core fields

    public var numStartups: Int
    public var theme: String?
    public var verbose: Bool?
    public var autoCompactEnabled: Bool?
    public var showTurnDuration: Bool?

    // MARK: Onboarding / state

    public var hasCompletedOnboarding: Bool?
    public var lastOnboardingVersion: String?
    public var lastReleaseNotesSeen: String?
    public var userID: String?
    public var installMethod: String?

    // MARK: Auto-updates

    public var autoUpdates: Bool?
    public var autoUpdatesProtectedForNative: Bool?

    // MARK: Permissions migration flags

    public var bypassPermissionsModeAccepted: Bool?

    // MARK: Memory usage

    public var memoryUsageCount: Int?

    // MARK: Projects map (path → ProjectConfig)

    public var projects: [String: ProjectConfig]?

    // MARK: Deprecated / legacy

    /// @deprecated Use settings.apiKeyHelper instead.
    public var apiKeyHelper: String?
    /// @deprecated Use settings.env instead.
    public var env: [String: String]?

    // MARK: Migration timestamps (written by migrations as guard fields)

    public var sonnet45To46MigrationTimestamp: Double?
    public var legacyOpusMigrationTimestamp: Double?

    // MARK: Extra fields (forward-compat round-trip)

    public var extraFields: [String: JSONValue]

    // MARK: - Init

    public init(numStartups: Int = 0) {
        self.numStartups = numStartups
        self.extraFields = [:]
    }

    // MARK: - Codable

    private static let knownKeys: Set<String> = [
        "numStartups","theme","verbose","autoCompactEnabled","showTurnDuration",
        "hasCompletedOnboarding","lastOnboardingVersion","lastReleaseNotesSeen",
        "userID","installMethod","autoUpdates","autoUpdatesProtectedForNative",
        "bypassPermissionsModeAccepted","memoryUsageCount","projects",
        "apiKeyHelper","env","sonnet45To46MigrationTimestamp","legacyOpusMigrationTimestamp"
    ]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        numStartups = try container.decodeIfPresent(Int.self, forKey: AnyCodingKey("numStartups")) ?? 0
        theme = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("theme"))
        verbose = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("verbose"))
        autoCompactEnabled = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("autoCompactEnabled"))
        showTurnDuration = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("showTurnDuration"))
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("hasCompletedOnboarding"))
        lastOnboardingVersion = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("lastOnboardingVersion"))
        lastReleaseNotesSeen = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("lastReleaseNotesSeen"))
        userID = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("userID"))
        installMethod = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("installMethod"))
        autoUpdates = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("autoUpdates"))
        autoUpdatesProtectedForNative = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("autoUpdatesProtectedForNative"))
        bypassPermissionsModeAccepted = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("bypassPermissionsModeAccepted"))
        memoryUsageCount = try container.decodeIfPresent(Int.self, forKey: AnyCodingKey("memoryUsageCount"))
        projects = try container.decodeIfPresent([String: ProjectConfig].self, forKey: AnyCodingKey("projects"))
        apiKeyHelper = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("apiKeyHelper"))
        env = try container.decodeIfPresent([String: String].self, forKey: AnyCodingKey("env"))
        sonnet45To46MigrationTimestamp = try container.decodeIfPresent(Double.self, forKey: AnyCodingKey("sonnet45To46MigrationTimestamp"))
        legacyOpusMigrationTimestamp = try container.decodeIfPresent(Double.self, forKey: AnyCodingKey("legacyOpusMigrationTimestamp"))

        var extra: [String: JSONValue] = [:]
        for key in container.allKeys where !Self.knownKeys.contains(key.stringValue) {
            extra[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        extraFields = extra
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encode(numStartups, forKey: AnyCodingKey("numStartups"))
        try container.encodeIfPresent(theme, forKey: AnyCodingKey("theme"))
        try container.encodeIfPresent(verbose, forKey: AnyCodingKey("verbose"))
        try container.encodeIfPresent(autoCompactEnabled, forKey: AnyCodingKey("autoCompactEnabled"))
        try container.encodeIfPresent(showTurnDuration, forKey: AnyCodingKey("showTurnDuration"))
        try container.encodeIfPresent(hasCompletedOnboarding, forKey: AnyCodingKey("hasCompletedOnboarding"))
        try container.encodeIfPresent(lastOnboardingVersion, forKey: AnyCodingKey("lastOnboardingVersion"))
        try container.encodeIfPresent(lastReleaseNotesSeen, forKey: AnyCodingKey("lastReleaseNotesSeen"))
        try container.encodeIfPresent(userID, forKey: AnyCodingKey("userID"))
        try container.encodeIfPresent(installMethod, forKey: AnyCodingKey("installMethod"))
        try container.encodeIfPresent(autoUpdates, forKey: AnyCodingKey("autoUpdates"))
        try container.encodeIfPresent(autoUpdatesProtectedForNative, forKey: AnyCodingKey("autoUpdatesProtectedForNative"))
        try container.encodeIfPresent(bypassPermissionsModeAccepted, forKey: AnyCodingKey("bypassPermissionsModeAccepted"))
        try container.encodeIfPresent(memoryUsageCount, forKey: AnyCodingKey("memoryUsageCount"))
        try container.encodeIfPresent(projects, forKey: AnyCodingKey("projects"))
        try container.encodeIfPresent(apiKeyHelper, forKey: AnyCodingKey("apiKeyHelper"))
        try container.encodeIfPresent(env, forKey: AnyCodingKey("env"))
        try container.encodeIfPresent(sonnet45To46MigrationTimestamp, forKey: AnyCodingKey("sonnet45To46MigrationTimestamp"))
        try container.encodeIfPresent(legacyOpusMigrationTimestamp, forKey: AnyCodingKey("legacyOpusMigrationTimestamp"))
        for (key, value) in extraFields {
            try container.encode(value, forKey: AnyCodingKey(key))
        }
    }

    // MARK: - Load / Save

    /// Load GlobalConfig from `~/.claude.json`. Returns a default config if not found.
    public static func load() throws -> GlobalConfig {
        let url = ConfigPaths.globalConfigPath()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return GlobalConfig()
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(GlobalConfig.self, from: data)
    }

    /// Save GlobalConfig to `~/.claude.json` atomically.
    public func save() throws {
        let url = ConfigPaths.globalConfigPath()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    /// Load → transform → save in one call (mirrors `saveGlobalConfig(current =>)` pattern).
    public static func update(_ transform: (inout GlobalConfig) -> Void) throws {
        var config = try load()
        transform(&config)
        try config.save()
    }
}
