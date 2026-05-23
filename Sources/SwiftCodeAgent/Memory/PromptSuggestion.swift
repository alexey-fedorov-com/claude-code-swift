/// PromptSuggestion — AI-powered prompt completions stub.
///
/// Surfaces prompt suggestions based on session context and stored memories.
/// Requires a backend inference call; stubbed until API is stable.
///
/// Mirrors `src/services/memory/promptSuggestion.ts`.

import Foundation

// MARK: - PromptSuggestion

public struct PromptSuggestion: Equatable, Sendable {
    public let text: String
    public let confidence: Double
    public let source: SuggestionSource

    public enum SuggestionSource: Equatable, Sendable {
        case history
        case memory
        case contextual
    }

    public init(text: String, confidence: Double = 1.0, source: SuggestionSource = .contextual) {
        self.text = text
        self.confidence = confidence
        self.source = source
    }
}

// MARK: - PromptSuggestionService

public protocol PromptSuggestionService: Sendable {
    /// Return ranked prompt completions for the given partial input.
    func suggest(
        partial: String,
        sessionID: String,
        memories: [MemoryEntry]
    ) async throws -> [PromptSuggestion]
}

// MARK: - StubPromptSuggestion

/// Returns an empty suggestion list until the real backend is connected.
public struct StubPromptSuggestion: PromptSuggestionService {
    public init() {}

    public func suggest(
        partial: String,
        sessionID: String,
        memories: [MemoryEntry]
    ) async throws -> [PromptSuggestion] {
        // TODO: call suggestion API or run local heuristics over `memories`
        return []
    }
}
