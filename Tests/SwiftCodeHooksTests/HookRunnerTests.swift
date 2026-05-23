/// HookRunnerTests — tests for HookRunner dispatch and PermissionDecision parsing.

import Testing
import Foundation
@testable import SwiftCodeHooks
import SwiftCodeNative
import SwiftCodeCore

// MARK: - PermissionDecisionTests

@Suite("PermissionDecision")
struct PermissionDecisionTests {

    @Test("isApproved works correctly")
    func isApproved() {
        #expect(PermissionDecision.approve.isApproved)
        #expect(!PermissionDecision.noop.isApproved)
        #expect(!PermissionDecision.block(message: "x").isApproved)
        #expect(!PermissionDecision.defer(message: "x").isApproved)
    }

    @Test("isBlocked works correctly")
    func isBlocked() {
        #expect(PermissionDecision.block(message: "no").isBlocked)
        #expect(!PermissionDecision.approve.isBlocked)
        #expect(!PermissionDecision.noop.isBlocked)
    }

    @Test("2.1.89: isDeferred works correctly")
    func isDeferred() {
        #expect(PermissionDecision.defer(message: "waiting").isDeferred)
        #expect(!PermissionDecision.approve.isDeferred)
        #expect(!PermissionDecision.block(message: "x").isDeferred)
    }
}

// MARK: - HookDecisionParserTests

@Suite("HookDecisionParser")
struct HookDecisionParserTests {

    @Test("exit 0 with no JSON = noop")
    func exitZeroNoJSON() {
        let decision = HookDecisionParser.parse(exitCode: 0, stdout: "", stderr: "")
        #expect(decision == .noop)
    }

    @Test("exit 1 = block")
    func exitOne() {
        let decision = HookDecisionParser.parse(exitCode: 1, stdout: "not allowed", stderr: "")
        if case .block(let msg) = decision {
            #expect(msg == "not allowed")
        } else {
            Issue.record("Expected .block, got \(decision)")
        }
    }

    @Test("exit 2 = block")
    func exitTwo() {
        let decision = HookDecisionParser.parse(exitCode: 2, stdout: "", stderr: "hard error")
        if case .block(let msg) = decision {
            #expect(msg == "hard error")
        } else {
            Issue.record("Expected .block, got \(decision)")
        }
    }

    @Test("exit 0 with JSON decision=approve = approve")
    func jsonApprove() {
        let stdout = #"{"decision":"approve"}"#
        let decision = HookDecisionParser.parse(exitCode: 0, stdout: stdout, stderr: "")
        #expect(decision == .approve)
    }

    @Test("exit 0 with JSON decision=block = block with message")
    func jsonBlock() {
        let stdout = #"{"decision":"block","message":"not on my watch"}"#
        let decision = HookDecisionParser.parse(exitCode: 0, stdout: stdout, stderr: "")
        if case .block(let msg) = decision {
            #expect(msg == "not on my watch")
        } else {
            Issue.record("Expected .block, got \(decision)")
        }
    }

    @Test("2.1.89: exit 0 with JSON decision=defer = defer")
    func jsonDefer() {
        let stdout = #"{"decision":"defer","message":"need approval"}"#
        let decision = HookDecisionParser.parse(exitCode: 0, stdout: stdout, stderr: "")
        if case .defer(let msg) = decision {
            #expect(msg == "need approval")
        } else {
            Issue.record("Expected .defer, got \(decision)")
        }
    }

    @Test("exit 0 with garbage stdout = noop")
    func garbageStdout() {
        let decision = HookDecisionParser.parse(exitCode: 0, stdout: "hello world", stderr: "")
        #expect(decision == .noop)
    }
}

// MARK: - HookRunnerTests

@Suite("HookRunner")
struct HookRunnerTests {

    @Test("no-op when no hooks configured")
    func noHooksConfigured() async throws {
        let runner = HookRunner(processRunner: ProcessRunner(), config: HookConfig())
        let event = HookEvent(type: .preToolUse, sessionId: "test")
        let results = try await runner.dispatch(event)
        #expect(results.isEmpty)
    }

    @Test("runs command hook and returns result")
    func commandHookRuns() async throws {
        let config = HookConfig(hooks: [
            "PreToolUse": [
                HookMatcher(
                    matcher: nil,
                    hooks: [HookCommand(type: "command", command: "echo 'hook ran'")]
                )
            ]
        ])

        let runner = HookRunner(processRunner: ProcessRunner(), config: config)
        let event = HookEvent(type: .preToolUse, sessionId: "test")
        let results = try await runner.dispatch(event)
        #expect(results.count == 1)
        #expect(results[0].decision == .noop)
    }

    @Test("matcher filters by tool name")
    func matcherFiltersToolName() async throws {
        let config = HookConfig(hooks: [
            "PreToolUse": [
                HookMatcher(
                    matcher: "Bash",
                    hooks: [HookCommand(type: "command", command: "exit 0")]
                )
            ]
        ])

        let runner = HookRunner(processRunner: ProcessRunner(), config: config)

        // Event with non-matching tool name
        let readEvent = HookEvent(
            type: .preToolUse,
            payload: ["tool_name": .string("Read")],
            sessionId: "test"
        )
        let readResults = try await runner.dispatch(readEvent)
        #expect(readResults.isEmpty)

        // Event with matching tool name
        let bashEvent = HookEvent(
            type: .preToolUse,
            payload: ["tool_name": .string("Bash")],
            sessionId: "test"
        )
        let bashResults = try await runner.dispatch(bashEvent)
        #expect(!bashResults.isEmpty)
    }

    @Test("hook blocking stops further hooks")
    func blockingStopsFurther() async throws {
        let config = HookConfig(hooks: [
            "PreToolUse": [
                HookMatcher(
                    matcher: nil,
                    hooks: [
                        HookCommand(type: "command", command: "exit 1"),
                        HookCommand(type: "command", command: "echo 'should not run'")
                    ]
                )
            ]
        ])

        let runner = HookRunner(processRunner: ProcessRunner(), config: config)
        let event = HookEvent(type: .preToolUse, sessionId: "test")
        let results = try await runner.dispatch(event)
        // Should stop after first blocking hook
        #expect(results.count == 1)
        #expect(results[0].decision.isBlocked)
    }
}
