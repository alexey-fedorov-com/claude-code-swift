import XCTest
@testable import SwiftCodeSettings
import SwiftCodeCore

final class MigrationTests: XCTestCase {

    // MARK: - MigrateAutoUpdatesToSettings

    func testAutoUpdatesMigrationRunsWhenAutoUpdatesIsFalse() throws {
        let migration = MigrateAutoUpdatesToSettings()
        var config = GlobalConfig(numStartups: 5)
        config.autoUpdates = false
        config.autoUpdatesProtectedForNative = false

        XCTAssertTrue(migration.shouldRun(config: config))

        var settings = SettingsSchema()
        migration.apply(config: &config, settings: &settings)

        // Guard field should be cleared
        XCTAssertNil(config.autoUpdates)
        // env var should be set
        XCTAssertEqual(settings.env?["DISABLE_AUTOUPDATER"], "1")
    }

    func testAutoUpdatesMigrationSkipsWhenProtected() {
        let migration = MigrateAutoUpdatesToSettings()
        var config = GlobalConfig(numStartups: 5)
        config.autoUpdates = false
        config.autoUpdatesProtectedForNative = true   // native protection → don't migrate

        XCTAssertFalse(migration.shouldRun(config: config))
    }

    func testAutoUpdatesMigrationSkipsWhenAutoUpdatesIsNil() {
        let migration = MigrateAutoUpdatesToSettings()
        var config = GlobalConfig(numStartups: 5)
        config.autoUpdates = nil

        XCTAssertFalse(migration.shouldRun(config: config))
    }

    func testAutoUpdatesMigrationSkipsWhenAutoUpdatesIsTrue() {
        let migration = MigrateAutoUpdatesToSettings()
        var config = GlobalConfig(numStartups: 5)
        config.autoUpdates = true

        XCTAssertFalse(migration.shouldRun(config: config))
    }

    // MARK: - MigrateBypassPermissionsAcceptedToSettings

    func testBypassPermissionsMigrationRunsWhenFlagIsTrue() {
        let migration = MigrateBypassPermissionsAcceptedToSettings()
        var config = GlobalConfig(numStartups: 3)
        config.bypassPermissionsModeAccepted = true

        XCTAssertTrue(migration.shouldRun(config: config))

        var settings = SettingsSchema()
        migration.apply(config: &config, settings: &settings)

        // Guard field cleared from GlobalConfig
        XCTAssertNil(config.bypassPermissionsModeAccepted)
        // skipDangerousModePermissionPrompt set in settings
        XCTAssertEqual(settings.skipDangerousModePermissionPrompt, true)
    }

    func testBypassPermissionsMigrationSkipsWhenFlagIsFalse() {
        let migration = MigrateBypassPermissionsAcceptedToSettings()
        var config = GlobalConfig(numStartups: 3)
        config.bypassPermissionsModeAccepted = false

        XCTAssertFalse(migration.shouldRun(config: config))
    }

    func testBypassPermissionsMigrationSkipsWhenFlagIsNil() {
        let migration = MigrateBypassPermissionsAcceptedToSettings()
        let config = GlobalConfig(numStartups: 3)

        XCTAssertFalse(migration.shouldRun(config: config))
    }

    // MARK: - Migration runs once then skips

    func testMigrationRunsOnceThenSkips() throws {
        let migration = MigrateAutoUpdatesToSettings()

        // First run: guard unset → should run
        var config = GlobalConfig(numStartups: 1)
        config.autoUpdates = false
        XCTAssertTrue(migration.shouldRun(config: config))

        var settings = SettingsSchema()
        migration.apply(config: &config, settings: &settings)

        // After applying, the guard field (autoUpdates) is cleared
        XCTAssertNil(config.autoUpdates)

        // Second run: guard field no longer set → shouldRun returns false
        XCTAssertFalse(migration.shouldRun(config: config))
    }

    // MARK: - Migration runner applies all pending migrations

    func testMigrationRunnerAppliesAllPending() {
        // Use a custom in-memory runner to avoid file I/O
        let runner = InMemoryMigrationRunner(
            migrations: [
                MigrateAutoUpdatesToSettings(),
                MigrateBypassPermissionsAcceptedToSettings(),
            ]
        )

        var config = GlobalConfig(numStartups: 2)
        config.autoUpdates = false
        config.bypassPermissionsModeAccepted = true

        var settings = SettingsSchema()
        runner.applyAll(config: &config, settings: &settings)

        XCTAssertNil(config.autoUpdates, "autoUpdates should be cleared after migration")
        XCTAssertNil(config.bypassPermissionsModeAccepted, "bypassPermissionsModeAccepted should be cleared after migration")
        XCTAssertEqual(settings.env?["DISABLE_AUTOUPDATER"], "1")
        XCTAssertEqual(settings.skipDangerousModePermissionPrompt, true)
    }
}

// MARK: - Test helper: in-memory migration runner

/// Applies migrations directly to in-memory structs, bypassing file I/O.
private struct InMemoryMigrationRunner {
    let migrations: [any Migration]

    func applyAll(config: inout GlobalConfig, settings: inout SettingsSchema) {
        for migration in migrations {
            guard migration.shouldRun(config: config) else { continue }
            migration.apply(config: &config, settings: &settings)
        }
    }
}
