import XCTest
import SwiftCodeCore
@testable import SwiftCodeSettings

final class SettingsSchemaTests: XCTestCase {

    // MARK: 1. Valid defaultMode values

    func testPermissionDefaultModeAcceptsValidValues() throws {
        for mode in ["default", "acceptEdits", "bypassPermissions", "dontAsk", "plan"] {
            let json = """
            { "permissions": { "defaultMode": "\(mode)" } }
            """.data(using: .utf8)!
            let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)
            XCTAssertNoThrow(try settings.validate(), "Expected '\(mode)' to be valid")
        }
    }

    // MARK: 2. "auto" rejected when TRANSCRIPT_CLASSIFIER is disabled

    func testPermissionDefaultModeRejectsAutoWhenClassifierDisabled() throws {
        let json = """
        { "permissions": { "defaultMode": "auto" } }
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)
        XCTAssertThrowsError(try settings.validate()) { error in
            let message = "\(error)"
            XCTAssertTrue(
                message.contains("auto") || message.contains("TRANSCRIPT_CLASSIFIER"),
                "Error should mention 'auto' or 'TRANSCRIPT_CLASSIFIER', got: \(message)"
            )
        }
    }

    // MARK: 3. cleanupPeriodDays: 0 is rejected

    func testCleanupPeriodDaysZeroIsRejected() throws {
        let json = """
        { "cleanupPeriodDays": 0 }
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)
        XCTAssertThrowsError(try settings.validate()) { error in
            let message = "\(error)"
            XCTAssertTrue(
                message.contains("session-persistence") || message.contains("cleanupPeriodDays"),
                "Error should mention session-persistence or cleanupPeriodDays, got: \(message)"
            )
        }
    }

    func testCleanupPeriodDaysPositiveIsAccepted() throws {
        let json = """
        { "cleanupPeriodDays": 7 }
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)
        XCTAssertNoThrow(try settings.validate())
        XCTAssertEqual(settings.cleanupPeriodDays, 7)
    }

    // MARK: 4. disableSkillShellExecution decodes as Boolean

    func testDisableSkillShellExecutionIsBoolean() throws {
        let json = """
        { "disableSkillShellExecution": true }
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)
        XCTAssertEqual(settings.disableSkillShellExecution, true)
    }

    func testDisableSkillShellExecutionFalseDecodes() throws {
        let json = """
        { "disableSkillShellExecution": false }
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)
        XCTAssertEqual(settings.disableSkillShellExecution, false)
    }

    // MARK: 5. Unknown fields preserved on round-trip

    func testUnknownFieldsArePreservedOnRoundTrip() throws {
        let json = """
        { "model": "claude-opus-4-7", "unknownField": "preserve me", "anotherExtra": 42 }
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)

        // Known field decoded correctly
        XCTAssertEqual(settings.model, "claude-opus-4-7")

        // Unknown fields captured
        XCTAssertEqual(settings.extraFields["unknownField"], .string("preserve me"))
        XCTAssertEqual(settings.extraFields["anotherExtra"], .int(42))

        // Re-encode and decode — extras must survive
        let reEncoded = try JSONEncoder().encode(settings)
        let reDecoded = try JSONDecoder().decode([String: JSONValue].self, from: reEncoded)

        XCTAssertNotNil(reDecoded["unknownField"], "unknownField must survive round-trip")
        XCTAssertNotNil(reDecoded["anotherExtra"], "anotherExtra must survive round-trip")
        XCTAssertEqual(reDecoded["model"], .string("claude-opus-4-7"))
    }

    // MARK: - Additional coverage

    func testPermissionsAllowAndDenyDecode() throws {
        let json = """
        { "permissions": { "allow": ["Bash(git:*)"], "deny": ["Bash(rm -rf:*)"] } }
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)
        XCTAssertEqual(settings.permissions?.allow, ["Bash(git:*)"])
        XCTAssertEqual(settings.permissions?.deny, ["Bash(rm -rf:*)"])
    }

    func testEnvDecodes() throws {
        let json = """
        { "env": { "ANTHROPIC_API_KEY": "sk-test", "DEBUG": "1" } }
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)
        XCTAssertEqual(settings.env?["ANTHROPIC_API_KEY"], "sk-test")
        XCTAssertEqual(settings.env?["DEBUG"], "1")
    }

    func testEmptySettingsDecodesWithoutError() throws {
        let json = "{}".data(using: .utf8)!
        let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)
        XCTAssertNil(settings.model)
        XCTAssertNil(settings.cleanupPeriodDays)
        XCTAssertNoThrow(try settings.validate())
    }

    func testUnknownDefaultModeIsRejected() throws {
        let json = """
        { "permissions": { "defaultMode": "superDangerousMode" } }
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(SettingsSchema.self, from: json)
        XCTAssertThrowsError(try settings.validate())
    }
}
