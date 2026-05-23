/// HookEventTests — tests for HookEvent types and HookConfig decoding.

import Testing
import Foundation
@testable import SwiftCodeHooks
import SwiftCodeCore

// MARK: - HookEventTypeTests

@Suite("HookEventType")
struct HookEventTypeTests {

    @Test("all event types have correct raw values")
    func rawValues() {
        #expect(HookEventType.preToolUse.rawValue == "PreToolUse")
        #expect(HookEventType.postToolUse.rawValue == "PostToolUse")
        #expect(HookEventType.notification.rawValue == "Notification")
        #expect(HookEventType.stop.rawValue == "Stop")
        #expect(HookEventType.subagentStop.rawValue == "SubagentStop")
        #expect(HookEventType.preCompact.rawValue == "PreCompact")
        #expect(HookEventType.sessionStart.rawValue == "SessionStart")
        #expect(HookEventType.sessionEnd.rawValue == "SessionEnd")
        #expect(HookEventType.userPromptSubmit.rawValue == "UserPromptSubmit")
        #expect(HookEventType.prompt.rawValue == "Prompt")
        #expect(HookEventType.permissionDenied.rawValue == "PermissionDenied")
    }

    @Test("2.1.89 backport: PermissionDenied is present in allCases")
    func permissionDeniedPresent() {
        #expect(HookEventType.allCases.contains(.permissionDenied))
    }

    @Test("allCases has 11 event types")
    func allCasesCount() {
        #expect(HookEventType.allCases.count == 11)
    }

    @Test("event types are Codable")
    func codable() throws {
        let encoded = try JSONEncoder().encode(HookEventType.preToolUse)
        let decoded = try JSONDecoder().decode(HookEventType.self, from: encoded)
        #expect(decoded == .preToolUse)
    }

    @Test("decodes from raw string value")
    func decodesFromString() throws {
        let json = #""PermissionDenied""#
        let decoded = try JSONDecoder().decode(HookEventType.self, from: Data(json.utf8))
        #expect(decoded == .permissionDenied)
    }
}

// MARK: - HookEventTests

@Suite("HookEvent")
struct HookEventTests {

    @Test("creates event with defaults")
    func defaultInit() {
        let event = HookEvent(type: .preToolUse, sessionId: "sess-1")
        #expect(event.type == .preToolUse)
        #expect(event.sessionId == "sess-1")
        #expect(event.payload.isEmpty)
    }

    @Test("creates event with payload")
    func withPayload() {
        let event = HookEvent(
            type: .postToolUse,
            payload: ["tool_name": .string("Bash"), "exit_code": .int(0)],
            sessionId: "sess-2"
        )
        #expect(event.payload["tool_name"] == .string("Bash"))
        #expect(event.payload["exit_code"] == .int(0))
    }
}

// MARK: - HookConfigTests

@Suite("HookConfig")
struct HookConfigTests {

    @Test("decodes hooks config from JSON")
    func decodesFromJSON() throws {
        let json = """
        {
          "PreToolUse": [
            {
              "matcher": "Bash",
              "hooks": [
                { "type": "command", "command": "echo hello" }
              ]
            }
          ],
          "Notification": [
            {
              "hooks": [
                { "type": "command", "command": "notify-send $CLAUDE_HOOK_EVENT" }
              ]
            }
          ]
        }
        """

        let config = try JSONDecoder().decode(HookConfig.self, from: Data(json.utf8))
        #expect(config.matchers(for: .preToolUse).count == 1)
        #expect(config.matchers(for: .notification).count == 1)
        #expect(config.matchers(for: .stop).isEmpty)

        let preToolMatcher = config.matchers(for: .preToolUse)[0]
        #expect(preToolMatcher.matcher == "Bash")
        #expect(preToolMatcher.hooks[0].type == "command")
        #expect(preToolMatcher.hooks[0].command == "echo hello")
    }

    @Test("hasHooks returns true when hooks are configured")
    func hasHooks() throws {
        let json = """
        { "Stop": [{ "hooks": [{"type":"command","command":"echo stop"}] }] }
        """
        let config = try JSONDecoder().decode(HookConfig.self, from: Data(json.utf8))
        #expect(config.hasHooks(for: .stop))
        #expect(!config.hasHooks(for: .sessionStart))
    }

    @Test("empty config returns empty matchers")
    func emptyConfig() {
        let config = HookConfig()
        for eventType in HookEventType.allCases {
            #expect(config.matchers(for: eventType).isEmpty)
        }
    }

    @Test("HookCommand decodes all fields")
    func hookCommandFields() throws {
        let json = """
        {
          "type": "command",
          "command": "echo test",
          "timeout": 30,
          "if": "Bash(git *)",
          "once": true,
          "async": false,
          "statusMessage": "Running hook..."
        }
        """
        let cmd = try JSONDecoder().decode(HookCommand.self, from: Data(json.utf8))
        #expect(cmd.type == "command")
        #expect(cmd.command == "echo test")
        #expect(cmd.timeout == 30)
        #expect(cmd.if == "Bash(git *)")
        #expect(cmd.once == true)
        #expect(cmd.async == false)
        #expect(cmd.statusMessage == "Running hook...")
    }
}
