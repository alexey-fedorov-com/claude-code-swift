// Compaction.swift
// SwiftCodeAgent
//
// Auto-compact with circuit breaker.
// Ports from .reference/src/services/compact/autoCompact.ts
//
// Key reference constants (autoCompact.ts):
//   AUTOCOMPACT_BUFFER_TOKENS         = 13_000
//   WARNING_THRESHOLD_BUFFER_TOKENS   = 20_000
//   ERROR_THRESHOLD_BUFFER_TOKENS     = 20_000
//   MANUAL_COMPACT_BUFFER_TOKENS      = 3_000
//   MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3   (circuit breaker — 2.1.89 backport)
//
// Microcompact (CACHED_MICROCOMPACT feature flag) and HISTORY_SNIP are
// disabled feature flags per CLAUDE.md — kept as stubs here.
// Session memory compaction (trySessionMemoryCompaction) is stubbed for Task 17.

import Foundation
import SwiftCodeCore
import SwiftCodeAPI

// MARK: - Compaction Thresholds
// Matches autoCompact.ts constants.

public enum CompactionThresholds {
    /// Tokens reserved for compaction summary output (p99.99 was 17,387 tokens).
    public static let maxOutputTokensForSummary = 20_000

    /// How many tokens below the effective context window to trigger compaction.
    public static let autocompactBuffer = 13_000

    /// Warning threshold buffer.
    public static let warningThresholdBuffer = 20_000

    /// Error threshold buffer.
    public static let errorThresholdBuffer = 20_000

    /// Manual compact buffer (smaller headroom for user-triggered /compact).
    public static let manualCompactBuffer = 3_000

    /// Circuit breaker: stop after this many consecutive failures. (2.1.89 backport)
    public static let maxConsecutiveFailures = 3
}

// MARK: - CompactionResult

public enum CompactionOutcome: Sendable {
    case success
    case failure(Error)
}

public struct CompactionResult: Sendable {
    public let originalMessageCount: Int
    public let compactedMessageCount: Int
    public let tokensFreed: Int
    public let outcome: CompactionOutcome

    public init(
        originalMessageCount: Int,
        compactedMessageCount: Int,
        tokensFreed: Int,
        outcome: CompactionOutcome
    ) {
        self.originalMessageCount = originalMessageCount
        self.compactedMessageCount = compactedMessageCount
        self.tokensFreed = tokensFreed
        self.outcome = outcome
    }
}

// MARK: - CompactionError

public enum CompactionError: Error, Sendable {
    /// Circuit breaker has opened after too many consecutive failures.
    /// Matches the 2.1.89 backport message from autoCompact.ts.
    case circuitBreakerOpen(message: String)

    /// Compaction was attempted but failed with no recovery path.
    case compactionFailed(underlying: Error)

    /// The session was aborted by the user during compaction.
    case userAborted
}

// MARK: - Compactor

/// Manages conversation compaction with a circuit breaker for thrash protection.
///
/// The circuit breaker was backported from 2.1.89 per CLAUDE.md. After
/// `CompactionThresholds.maxConsecutiveFailures` consecutive failures, all
/// subsequent compact calls throw `CompactionError.circuitBreakerOpen` with
/// an actionable message. A single success resets the counter.
///
/// Actual summarization is stubbed (TODO: implement summarization in Task 13/17).
/// The interface and circuit breaker logic match the reference exactly.
public actor Compactor {

    private let client: any AnthropicAPI
    private let model: String

    /// Number of consecutive auto-compact failures. Reset on success.
    private var consecutiveFailures: Int = 0

    /// Whether the circuit breaker is open (too many consecutive failures).
    private var circuitBreakerOpen: Bool = false

    public init(client: any AnthropicAPI, model: String) {
        self.client = client
        self.model = model
    }

    // MARK: Public Interface

    /// Attempt to compact the message array.
    ///
    /// Returns a compacted message array. If the circuit breaker has tripped,
    /// throws `CompactionError.circuitBreakerOpen` with an actionable message
    /// (matches the 2.1.89 backport in autoCompact.ts).
    ///
    /// - Parameter messages:  The full conversation message array.
    /// - Returns: A compacted (shorter) message array.
    /// - Throws:  `CompactionError.circuitBreakerOpen` if circuit is tripped.
    public func compact(_ messages: [Message]) async throws -> [Message] {
        if circuitBreakerOpen {
            throw CompactionError.circuitBreakerOpen(
                message: circuitBreakerMessage()
            )
        }

        do {
            let compacted = try await performCompaction(messages)
            // Success — reset the circuit breaker counter
            consecutiveFailures = 0
            return compacted
        } catch {
            consecutiveFailures += 1
            if consecutiveFailures >= CompactionThresholds.maxConsecutiveFailures {
                circuitBreakerOpen = true
                // Log the circuit breaker trip (mirrors autoCompact.ts warn log)
                // In production this would go to the logger
                _ = circuitBreakerMessage()
            }
            throw CompactionError.compactionFailed(underlying: error)
        }
    }

    /// Record the outcome of a compaction attempt.
    /// Used by callers that manage their own retry loop.
    ///
    /// - Parameter result: The result of the compaction attempt.
    public func recordResult(_ result: CompactionResult) {
        switch result.outcome {
        case .success:
            consecutiveFailures = 0
            circuitBreakerOpen = false
        case .failure:
            consecutiveFailures += 1
            if consecutiveFailures >= CompactionThresholds.maxConsecutiveFailures {
                circuitBreakerOpen = true
            }
        }
    }

    /// Returns true if the circuit breaker is currently open.
    public var isCircuitBreakerOpen: Bool {
        circuitBreakerOpen
    }

    /// Returns the current consecutive failure count.
    public var failureCount: Int {
        consecutiveFailures
    }

    /// Reset the circuit breaker (e.g. after a new session starts).
    public func resetCircuitBreaker() {
        consecutiveFailures = 0
        circuitBreakerOpen = false
    }

    // MARK: - Private

    /// Performs the actual compaction.
    ///
    /// TODO (Task 13/17): implement real summarization by calling the API
    /// with a summarize-the-conversation prompt, similar to compact.ts.
    /// For now returns a stub that keeps only the last N messages.
    private func performCompaction(_ messages: [Message]) async throws -> [Message] {
        // Stub: keep only the most recent messages with a synthetic summary at start
        // Real implementation calls Anthropic API to summarize the conversation.
        let keepCount = min(20, messages.count)
        if messages.count <= keepCount {
            return messages
        }

        let summary = UserMessage(
            uuid: UUID().uuidString,
            content: .text("[Conversation compacted: \(messages.count - keepCount) earlier messages summarized]"),
            isMeta: true
        )

        let recent = Array(messages.suffix(keepCount))
        return [.user(summary)] + recent
    }

    /// The actionable error message when the circuit breaker trips.
    /// Matches the exact message format from autoCompact.ts (2.1.89 backport):
    /// "context refilled to the limit immediately after compacting N times in a row..."
    private func circuitBreakerMessage() -> String {
        return """
        Auto-compact has failed \(CompactionThresholds.maxConsecutiveFailures) times in a row. \
        This usually means the conversation has too much non-compactable content \
        (e.g. large tool results, many system messages). \
        Try: (1) start a new session with /clear, \
        (2) reduce the number of large tool results, \
        or (3) increase the model's context window.
        """
    }
}

// MARK: - Token Estimation Helpers

/// Rough token count estimation for a message array.
/// The reference (tokenCountWithEstimation) uses tiktoken / cl100k_base.
/// This is a conservative approximation: ~4 chars per token on average.
/// Used to decide whether to trigger compaction.
public func estimateTokenCount(_ messages: [Message]) -> Int {
    var totalChars = 0
    for message in messages {
        switch message {
        case .user(let msg):
            switch msg.content {
            case .text(let t):
                totalChars += t.count
            case .toolResult(_, let content):
                for block in content {
                    if case .text(let t) = block { totalChars += t.count }
                }
            case .image:
                totalChars += 1000 // rough estimate for image tokens
            }
        case .assistant(let msg):
            for block in msg.content {
                switch block {
                case .text(let t): totalChars += t.count
                case .thinking(let t, _): totalChars += t.count
                case .toolUse(_, _, let input):
                    // rough: JSON-encode the input
                    totalChars += input.description.count
                }
            }
        case .system(let msg):
            totalChars += msg.text.count
        case .progress:
            break
        }
    }
    // ~4 chars per token is a conservative approximation
    return totalChars / 4
}

/// Determines if autocompaction should trigger based on current token count
/// and the model's effective context window.
///
/// Mirrors the `shouldAutoCompact` logic in autoCompact.ts.
public func shouldAutoCompact(messages: [Message], modelContextWindow: Int) -> Bool {
    let tokenCount = estimateTokenCount(messages)
    let effectiveWindow = modelContextWindow - CompactionThresholds.maxOutputTokensForSummary
    let threshold = effectiveWindow - CompactionThresholds.autocompactBuffer
    return tokenCount >= threshold
}
