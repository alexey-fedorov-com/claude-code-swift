// CompactionTests.swift
// SwiftCodeAgentTests
//
// Tests for Compactor circuit breaker (2.1.89 backport requirement).

import Testing
import Foundation
@testable import SwiftCodeAgent
import SwiftCodeCore
import SwiftCodeAPI

// MARK: - Mock AnthropicAPI for Tests

/// A mock that always succeeds — used to test Compactor in isolation.
final class MockCompactingClient: AnthropicAPI, @unchecked Sendable {
    func messages(_ request: MessagesRequest) async throws -> MessagesResponse {
        return MessagesResponse(
            id: "msg_test",
            type: "message",
            role: "assistant",
            content: [ContentBlock(type: "text", text: "Compacted.")],
            model: request.model,
            stopReason: "end_turn",
            stopSequence: nil,
            usage: UsageResponse(inputTokens: 10, outputTokens: 5)
        )
    }

    nonisolated func messagesStream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

// MARK: - Failing Compactor Subclass for Circuit Breaker Tests

/// A Compactor subclass that always fails compaction — used to test the circuit breaker.
actor AlwaysFailingCompactor: Sendable {
    private var consecutiveFailures: Int = 0
    private var circuitBreakerIsOpen: Bool = false

    func compact(_ messages: [Message]) async throws -> [Message] {
        if circuitBreakerIsOpen {
            throw CompactionError.circuitBreakerOpen(message: circuitBreakerMessage())
        }
        consecutiveFailures += 1
        if consecutiveFailures >= CompactionThresholds.maxConsecutiveFailures {
            circuitBreakerIsOpen = true
        }
        throw CompactionError.compactionFailed(underlying: NSError(domain: "test", code: -1))
    }

    var failureCount: Int { consecutiveFailures }
    var isCircuitBreakerOpen: Bool { circuitBreakerIsOpen }

    private func circuitBreakerMessage() -> String {
        return "Auto-compact has failed \(CompactionThresholds.maxConsecutiveFailures) times in a row. " +
               "Try: (1) start a new session with /clear, " +
               "(2) reduce the number of large tool results, " +
               "or (3) increase the model's context window."
    }
}

// MARK: - Tests

@Suite("Compaction")
struct CompactionTests {

    // MARK: - Threshold Constants

    @Test("Autocompact buffer token constant is correct")
    func testAutocompactBufferConstant() {
        #expect(CompactionThresholds.autocompactBuffer == 13_000)
    }

    @Test("Max consecutive failures constant is 3 (2.1.89 backport)")
    func testMaxConsecutiveFailuresConstant() {
        // This constant is critical — it matches the reference autoCompact.ts
        // MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3
        #expect(CompactionThresholds.maxConsecutiveFailures == 3)
    }

    // MARK: - Circuit Breaker (Core 2.1.89 Backport Requirement)

    @Test("First compaction attempt succeeds without circuit breaker interference")
    func testFirstCompactSucceedsWithoutCircuit() async throws {
        let client = MockCompactingClient()
        let compactor = Compactor(client: client, model: "claude-opus-4-6")

        let messages = makeTestMessages(count: 5)
        let result = try await compactor.compact(messages)

        // Should return compacted messages (stub keeps last N)
        #expect(!result.isEmpty)
        #expect(await compactor.isCircuitBreakerOpen == false)
        #expect(await compactor.failureCount == 0)
    }

    @Test("Circuit breaker opens after three consecutive failures")
    func testCircuitBreakerOpensAfterThreeFailures() async {
        let compactor = AlwaysFailingCompactor()
        let messages = makeTestMessages(count: 10)

        // First failure
        do {
            _ = try await compactor.compact(messages)
            Issue.record("Expected failure 1")
        } catch CompactionError.compactionFailed {
            // expected
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
        #expect(await compactor.isCircuitBreakerOpen == false)
        #expect(await compactor.failureCount == 1)

        // Second failure
        do {
            _ = try await compactor.compact(messages)
            Issue.record("Expected failure 2")
        } catch CompactionError.compactionFailed {
            // expected
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
        #expect(await compactor.isCircuitBreakerOpen == false)
        #expect(await compactor.failureCount == 2)

        // Third failure — circuit breaker trips
        do {
            _ = try await compactor.compact(messages)
            Issue.record("Expected failure 3")
        } catch CompactionError.compactionFailed {
            // expected on the third attempt
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
        #expect(await compactor.isCircuitBreakerOpen == true)
        #expect(await compactor.failureCount == 3)

        // Fourth call — should throw circuitBreakerOpen, NOT compactionFailed
        do {
            _ = try await compactor.compact(messages)
            Issue.record("Expected circuitBreakerOpen error")
        } catch CompactionError.circuitBreakerOpen(let message) {
            #expect(!message.isEmpty, "Circuit breaker message should not be empty")
            #expect(message.contains("/clear") || message.contains("new session"),
                    "Message should include actionable guidance")
        } catch {
            Issue.record("Wrong error type after circuit breaker: \(error)")
        }
    }

    @Test("Circuit breaker message includes actionable guidance")
    func testCircuitBreakerMessageIsActionable() async {
        let compactor = AlwaysFailingCompactor()
        let messages = makeTestMessages(count: 5)

        // Trigger 3 failures to open circuit
        for _ in 0..<3 {
            try? await compactor.compact(messages)
        }

        // 4th call should be circuitBreakerOpen with useful message
        do {
            _ = try await compactor.compact(messages)
        } catch CompactionError.circuitBreakerOpen(let msg) {
            // The message must include actionable steps (from 2.1.89 backport)
            let hasActionableContent = msg.contains("/clear") ||
                                       msg.contains("new session") ||
                                       msg.contains("restart")
            #expect(hasActionableContent,
                    "Circuit breaker message should include actionable guidance. Got: \(msg)")
            #expect(msg.contains("3") || msg.contains("times"),
                    "Message should mention the failure count")
        } catch {
            Issue.record("Expected circuitBreakerOpen, got: \(error)")
        }
    }

    @Test("Success resets circuit breaker failure count")
    func testSuccessResetsCircuit() async throws {
        let client = MockCompactingClient()
        let compactor = Compactor(client: client, model: "claude-opus-4-6")

        // Manually record partial failures via recordResult
        await compactor.recordResult(CompactionResult(
            originalMessageCount: 10,
            compactedMessageCount: 5,
            tokensFreed: 1000,
            outcome: .failure(NSError(domain: "test", code: 1))
        ))
        await compactor.recordResult(CompactionResult(
            originalMessageCount: 10,
            compactedMessageCount: 5,
            tokensFreed: 1000,
            outcome: .failure(NSError(domain: "test", code: 1))
        ))

        #expect(await compactor.failureCount == 2)
        #expect(await compactor.isCircuitBreakerOpen == false)

        // Record a success — should reset the counter
        await compactor.recordResult(CompactionResult(
            originalMessageCount: 10,
            compactedMessageCount: 5,
            tokensFreed: 1000,
            outcome: .success
        ))

        #expect(await compactor.failureCount == 0,
                "Failure count should reset to 0 after success")
        #expect(await compactor.isCircuitBreakerOpen == false)
    }

    @Test("Three failures set circuit breaker via recordResult")
    func testRecordResultThreeFailuresOpenCircuit() async {
        let client = MockCompactingClient()
        let compactor = Compactor(client: client, model: "claude-opus-4-6")

        let failureResult = CompactionResult(
            originalMessageCount: 10,
            compactedMessageCount: 5,
            tokensFreed: 0,
            outcome: .failure(NSError(domain: "test", code: 1))
        )

        await compactor.recordResult(failureResult)
        await compactor.recordResult(failureResult)
        #expect(await compactor.isCircuitBreakerOpen == false)

        await compactor.recordResult(failureResult)
        #expect(await compactor.isCircuitBreakerOpen == true,
                "Circuit breaker should open after 3 failures via recordResult")
    }

    // MARK: - Token Estimation

    @Test("Token estimation returns non-zero for non-empty messages")
    func testTokenEstimationNonZero() {
        let messages = makeTestMessages(count: 3)
        let count = estimateTokenCount(messages)
        #expect(count > 0)
    }

    @Test("Token estimation scales with message count")
    func testTokenEstimationScales() {
        let small = makeTestMessages(count: 2)
        let large = makeTestMessages(count: 10)
        let smallCount = estimateTokenCount(small)
        let largeCount = estimateTokenCount(large)
        #expect(largeCount > smallCount)
    }

    @Test("shouldAutoCompact returns false for small conversation")
    func testShouldAutoCompactFalseForSmall() {
        let messages = makeTestMessages(count: 3)
        let result = shouldAutoCompact(messages: messages, modelContextWindow: 200_000)
        #expect(result == false, "Small conversation should not trigger compaction")
    }

    // MARK: - Compactor Reset

    @Test("Reset circuit breaker clears state")
    func testResetCircuitBreaker() async {
        let client = MockCompactingClient()
        let compactor = Compactor(client: client, model: "claude-opus-4-6")

        // Open the circuit breaker via recordResult
        let failureResult = CompactionResult(
            originalMessageCount: 10,
            compactedMessageCount: 5,
            tokensFreed: 0,
            outcome: .failure(NSError(domain: "test", code: 1))
        )
        for _ in 0..<3 {
            await compactor.recordResult(failureResult)
        }
        #expect(await compactor.isCircuitBreakerOpen == true)

        // Reset
        await compactor.resetCircuitBreaker()
        #expect(await compactor.isCircuitBreakerOpen == false)
        #expect(await compactor.failureCount == 0)
    }

    // MARK: - Helpers

    private func makeTestMessages(count: Int) -> [Message] {
        var messages: [Message] = []
        for i in 0..<count {
            let user = UserMessage(
                uuid: UUID().uuidString,
                content: .text("User message \(i): The quick brown fox jumps over the lazy dog. " +
                               "This is additional text to make the message longer for token estimation."),
                isMeta: false
            )
            messages.append(.user(user))

            let assistant = AssistantMessage(
                uuid: UUID().uuidString,
                content: [.text("Assistant response \(i): Here is my detailed answer with some content.")],
                usage: Usage(inputTokens: 100, outputTokens: 50),
                stopReason: .endTurn
            )
            messages.append(.assistant(assistant))
        }
        return messages
    }
}
