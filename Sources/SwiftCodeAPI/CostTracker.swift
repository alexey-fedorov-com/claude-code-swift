import SwiftCodeCore

// MARK: - UsageRecord

/// A single accumulated usage entry for one model.
public struct UsageRecord: Sendable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var cacheWriteTokens: Int
    public var webSearchRequests: Int

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheReadTokens: Int = 0,
        cacheWriteTokens: Int = 0,
        webSearchRequests: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.webSearchRequests = webSearchRequests
    }
}

// MARK: - CostTracker

/// Accumulates token usage across multiple API calls and computes USD cost.
/// Thread-safe actor — matches the role of the TypeScript state management in
/// bootstrap/state.ts and the cost calculation in utils/modelCost.ts.
public actor CostTracker {

    // MARK: State

    private var records: [String: UsageRecord] = [:]
    private var hasUnknownModelCost: Bool = false

    // MARK: Init

    public init() {}

    // MARK: Recording

    /// Record token usage for a given model ID.
    /// The model ID may be a canonical first-party ID or an alias; it will be resolved.
    public func record(modelId: String, usage: Usage) {
        let canonical = ModelRegistry.canonicalID(modelId) ?? modelId
        var rec = records[canonical] ?? UsageRecord()
        rec.inputTokens       += usage.inputTokens
        rec.outputTokens      += usage.outputTokens
        rec.cacheReadTokens   += usage.cacheReadInputTokens ?? 0
        rec.cacheWriteTokens  += usage.cacheCreationInputTokens ?? 0
        records[canonical] = rec
    }

    /// Record usage with explicit web search count.
    public func record(modelId: String, usage: Usage, webSearchRequests: Int) {
        record(modelId: modelId, usage: usage)
        let canonical = ModelRegistry.canonicalID(modelId) ?? modelId
        records[canonical, default: UsageRecord()].webSearchRequests += webSearchRequests
    }

    // MARK: Totals

    /// Total cost in USD across all models.
    public func totalUSD() -> Double {
        records.reduce(0.0) { sum, pair in
            sum + cost(for: pair.key, record: pair.value)
        }
    }

    /// Per-model breakdown: modelId → (costUSD, totalTokens).
    public func breakdown() -> [String: (cost: Double, tokens: Int)] {
        var result: [String: (cost: Double, tokens: Int)] = [:]
        for (modelId, rec) in records {
            let tokens = rec.inputTokens + rec.outputTokens
                       + rec.cacheReadTokens + rec.cacheWriteTokens
            result[modelId] = (cost: cost(for: modelId, record: rec), tokens: tokens)
        }
        return result
    }

    /// Per-model usage records.
    public func usageRecords() -> [String: UsageRecord] {
        return records
    }

    /// Whether any recorded model had unknown pricing.
    public func unknownModelCostDetected() -> Bool {
        return hasUnknownModelCost
    }

    /// Reset all accumulated state (useful between sessions/tests).
    public func reset() {
        records = [:]
        hasUnknownModelCost = false
    }

    // MARK: Private helpers

    /// Calculate cost for a single (modelId, record) pair.
    private func cost(for modelId: String, record: UsageRecord) -> Double {
        guard let info = ModelRegistry.resolve(modelId) else {
            hasUnknownModelCost = true
            // Fall back to default main-loop model pricing
            let fallback = ModelRegistry.defaultMainLoopModel
            return computeCost(info: fallback, record: record)
        }
        return computeCost(info: info, record: record)
    }

    private func computeCost(info: ModelInfo, record: UsageRecord) -> Double {
        let mtok = 1_000_000.0
        var total = 0.0
        total += Double(record.inputTokens) / mtok * info.inputCostPer1MTokens
        total += Double(record.outputTokens) / mtok * info.outputCostPer1MTokens
        if let cacheRead = info.cacheReadCostPer1MTokens {
            total += Double(record.cacheReadTokens) / mtok * cacheRead
        }
        if let cacheWrite = info.cacheWriteCostPer1MTokens {
            total += Double(record.cacheWriteTokens) / mtok * cacheWrite
        }
        total += Double(record.webSearchRequests) * info.webSearchCostPerRequest
        return total
    }
}

// MARK: - CostFormatter

/// Utility to format cost values for display.
public enum CostFormatter {
    /// Format a USD cost value for human display.
    /// Matches the TypeScript `formatCost` convention: show cents for small values.
    public static func format(_ usd: Double) -> String {
        if usd == 0 { return "$0.00" }
        return String(format: "$%.4f", usd)
    }
}
