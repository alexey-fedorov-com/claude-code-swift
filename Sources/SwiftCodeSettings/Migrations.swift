/// Migrations — settings migration framework.
///
/// Mirrors the migration pattern from `src/migrations/*.ts`.
/// Each migration has an ID and a guard check. Migrations run once; after
/// running, a guard field is set in GlobalConfig so the migration won't
/// repeat on the next launch.
///
/// Ported migrations:
///   1. migrateAutoUpdatesToSettings — moves `autoUpdates: false` to settings.json env var
///   2. migrateBypassPermissionsAcceptedToSettings — moves `bypassPermissionsModeAccepted` to settings.json
///   3. migrateSonnet45ToSonnet46 — updates explicit Sonnet 4.5 model string to 'sonnet' alias
///   4. migrateLegacyOpusToCurrent — cleans up pinned Opus 4.0/4.1 model strings
///
/// Note: Migrations that require API calls (provider checks, subscriber status) are
/// marked as TODO — they need the SwiftCodeAPI and SwiftCodeAgent modules to be complete.

import Foundation
import SwiftCodeCore

// MARK: - Migration Protocol

/// A settings migration.
///
/// Implement `shouldRun(config:)` to guard against re-running,
/// and `apply(config:settings:)` to perform the actual change.
public protocol Migration: Sendable {
    /// Unique stable identifier for this migration.
    var id: String { get }

    /// Returns `true` if this migration needs to run (i.e., guard field is unset).
    func shouldRun(config: GlobalConfig) -> Bool

    /// Apply the migration. Receives mutable copies of GlobalConfig and the
    /// user SettingsSchema; modify them and return. Both are saved by MigrationRunner.
    func apply(config: inout GlobalConfig, settings: inout SettingsSchema)
}

// MARK: - Migration Runner

public struct MigrationRunner {

    private let migrations: [any Migration]

    public init(migrations: [any Migration] = MigrationRunner.allMigrations) {
        self.migrations = migrations
    }

    /// Run all pending migrations. Loads, applies, and saves GlobalConfig + userSettings.
    public func runAll() {
        // Load current state
        var config: GlobalConfig
        do {
            config = try GlobalConfig.load()
        } catch {
            // If we can't read the global config, skip migrations silently.
            return
        }

        var userSettings: SettingsSchema
        do {
            userSettings = try SettingsLoader.loadFile(at: ConfigPaths.userSettingsPath()) ?? SettingsSchema()
        } catch {
            userSettings = SettingsSchema()
        }

        var configChanged = false
        var settingsChanged = false

        for migration in migrations {
            guard migration.shouldRun(config: config) else { continue }

            let configBefore = config
            let settingsBefore = userSettings

            migration.apply(config: &config, settings: &userSettings)
            configChanged = configChanged || !configEqual(configBefore, config)
            settingsChanged = settingsChanged || !settingsEqual(settingsBefore, userSettings)
        }

        // Persist changes
        if configChanged {
            try? config.save()
        }
        if settingsChanged {
            try? SettingsLoader.saveFile(userSettings, to: ConfigPaths.userSettingsPath())
        }
    }

    /// All built-in migrations in run order.
    public static let allMigrations: [any Migration] = [
        MigrateAutoUpdatesToSettings(),
        MigrateBypassPermissionsAcceptedToSettings(),
        // Model-string migrations need subscriber checks → TODO after SwiftCodeAPI lands.
        // MigrateSonnet45ToSonnet46(),
        // MigrateLegacyOpusToCurrent(),
    ]

    // MARK: - Helpers

    /// Shallow equality check for GlobalConfig (used to decide if save is needed).
    private func configEqual(_ a: GlobalConfig, _ b: GlobalConfig) -> Bool {
        // Use encode-then-compare as a reliable but cheap structural check.
        guard let da = try? JSONEncoder().encode(a),
              let db = try? JSONEncoder().encode(b) else { return false }
        return da == db
    }

    private func settingsEqual(_ a: SettingsSchema, _ b: SettingsSchema) -> Bool {
        guard let da = try? JSONEncoder().encode(a),
              let db = try? JSONEncoder().encode(b) else { return false }
        return da == db
    }
}

// MARK: - Concrete Migrations

// MARK: 1. MigrateAutoUpdatesToSettings

/// Moves `autoUpdates: false` from GlobalConfig to `env.DISABLE_AUTOUPDATER = "1"` in settings.json.
/// Guard: `config.autoUpdates` must be `false` AND `autoUpdatesProtectedForNative` must be `false`/nil.
///
/// Mirrors `migrateAutoUpdatesToSettings()` from `src/migrations/migrateAutoUpdatesToSettings.ts`.
public struct MigrateAutoUpdatesToSettings: Migration {
    public let id = "migrateAutoUpdatesToSettings"

    public init() {}

    public func shouldRun(config: GlobalConfig) -> Bool {
        // Only run when autoUpdates was explicitly set to false by user preference,
        // not when it was disabled to protect a native installation.
        return config.autoUpdates == false && config.autoUpdatesProtectedForNative != true
    }

    public func apply(config: inout GlobalConfig, settings: inout SettingsSchema) {
        // Set DISABLE_AUTOUPDATER env var in user settings
        var env = settings.env ?? [:]
        env["DISABLE_AUTOUPDATER"] = "1"
        settings.env = env

        // Remove the migrated fields from GlobalConfig
        config.autoUpdates = nil
        config.autoUpdatesProtectedForNative = nil
    }
}

// MARK: 2. MigrateBypassPermissionsAcceptedToSettings

/// Moves `bypassPermissionsModeAccepted: true` from GlobalConfig to
/// `skipDangerousModePermissionPrompt: true` in settings.json.
/// Guard: `config.bypassPermissionsModeAccepted` must be true.
///
/// Mirrors `migrateBypassPermissionsAcceptedToSettings()` from reference migrations.
public struct MigrateBypassPermissionsAcceptedToSettings: Migration {
    public let id = "migrateBypassPermissionsAcceptedToSettings"

    public init() {}

    public func shouldRun(config: GlobalConfig) -> Bool {
        return config.bypassPermissionsModeAccepted == true
    }

    public func apply(config: inout GlobalConfig, settings: inout SettingsSchema) {
        // Only set if not already set in user settings
        if settings.skipDangerousModePermissionPrompt != true {
            settings.skipDangerousModePermissionPrompt = true
        }
        // Remove the old field from GlobalConfig
        config.bypassPermissionsModeAccepted = nil
    }
}

// MARK: 3. MigrateSonnet45ToSonnet46 (TODO: requires subscriber check)

/// TODO: Port this migration after SwiftCodeAPI is complete.
/// Migrates explicit Sonnet 4.5 model strings to the 'sonnet' alias (→ Sonnet 4.6).
/// Requires: provider = firstParty AND (Pro | Max | TeamPremium) subscriber.
///
/// Reference: `src/migrations/migrateSonnet45ToSonnet46.ts`

// MARK: 4. MigrateLegacyOpusToCurrent (TODO: requires provider check)

/// TODO: Port this migration after SwiftCodeAPI is complete.
/// Migrates explicit Opus 4.0/4.1 model strings to the 'opus' alias.
/// Requires: provider = firstParty AND legacy remap enabled.
///
/// Reference: `src/migrations/migrateLegacyOpusToCurrent.ts`
