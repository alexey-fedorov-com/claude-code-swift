/// AutoDream — background memory consolidation stub.
///
/// In the TypeScript source, "auto-dream" runs a background LLM pass after
/// each session to compress and consolidate memories. Needs backend infra and
/// a stable API contract before it can be implemented.
///
/// Mirrors `src/services/memory/autoDream.ts`.

import Foundation

// MARK: - DreamResult

public struct DreamResult: Sendable {
    public let consolidated: [ExtractedMemory]
    public let removed: [String]      // IDs of entries that were merged/removed
    public let sessionID: String

    public init(consolidated: [ExtractedMemory] = [], removed: [String] = [], sessionID: String) {
        self.consolidated = consolidated
        self.removed = removed
        self.sessionID = sessionID
    }
}

// MARK: - AutoDreamService

public protocol AutoDreamService: Sendable {
    /// Run memory consolidation for a completed session.
    func dream(sessionID: String, entries: [MemoryEntry]) async throws -> DreamResult
}

// MARK: - StubAutoDream

/// Stub — no-ops until the backend consolidation API is available.
public struct StubAutoDream: AutoDreamService {
    public init() {}

    public func dream(sessionID: String, entries: [MemoryEntry]) async throws -> DreamResult {
        // TODO: POST /v1/memory/consolidate with session entries
        // Real implementation uses a long-context model pass to
        // merge duplicate entries and prune stale facts.
        return DreamResult(sessionID: sessionID)
    }
}
