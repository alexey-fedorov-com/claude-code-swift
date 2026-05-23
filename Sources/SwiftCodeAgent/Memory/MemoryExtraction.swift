/// MemoryExtraction — extract durable memories from conversation turns.
///
/// Stub — real implementation calls the Claude API with a memory-extraction
/// system prompt. TODO when API contract is finalised.
///
/// Mirrors `src/services/memory/memoryExtraction.ts`.

import Foundation

// MARK: - ExtractedMemory

public struct ExtractedMemory: Codable, Equatable, Sendable {
    public let key: String
    public let value: String
    public let confidence: Double    // 0.0 – 1.0
    public let source: String        // e.g. "conversation_turn_3"

    public init(key: String, value: String, confidence: Double = 1.0, source: String = "") {
        self.key = key
        self.value = value
        self.confidence = confidence
        self.source = source
    }
}

// MARK: - MemoryExtractionService

public protocol MemoryExtractionService: Sendable {
    /// Extract durable memories from a conversation transcript.
    ///
    /// - Parameter transcript: Plain-text conversation turns.
    /// - Returns: List of extracted key-value memories.
    func extract(from transcript: String) async throws -> [ExtractedMemory]
}

// MARK: - StubMemoryExtraction

/// Always returns an empty list until the real LLM call is wired up.
public struct StubMemoryExtraction: MemoryExtractionService {
    public init() {}

    public func extract(from transcript: String) async throws -> [ExtractedMemory] {
        // TODO: call Claude API with memory-extraction prompt
        // System prompt template is in src/services/memory/extractionPrompt.txt
        return []
    }
}
