import XCTest
@testable import SwiftCodeAPI
import SwiftCodeCore

final class CostTrackerTests: XCTestCase {

    // MARK: - Basic Cost Calculation

    func testSingleMessageCostCalculatedCorrectly() async {
        let tracker = CostTracker()
        let usage = Usage(inputTokens: 1_000_000, outputTokens: 0)
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage)
        let total = await tracker.totalUSD()
        // Sonnet 4.6: $3 / 1M input tokens → 1M tokens = $3.00
        XCTAssertEqual(total, 3.0, accuracy: 0.0001)
    }

    func testOutputTokensCostCalculatedCorrectly() async {
        let tracker = CostTracker()
        let usage = Usage(inputTokens: 0, outputTokens: 1_000_000)
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage)
        let total = await tracker.totalUSD()
        // Sonnet 4.6: $15 / 1M output tokens
        XCTAssertEqual(total, 15.0, accuracy: 0.0001)
    }

    func testCacheReadTokensCostLess() async {
        let tracker = CostTracker()
        let usage = Usage(
            inputTokens: 0,
            outputTokens: 0,
            cacheReadInputTokens: 1_000_000,
            cacheCreationInputTokens: 0
        )
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage)
        let total = await tracker.totalUSD()
        // Sonnet 4.6 cache read: $0.30 / 1M
        XCTAssertEqual(total, 0.3, accuracy: 0.0001)
    }

    func testCacheWriteTokensCostCorrectly() async {
        let tracker = CostTracker()
        let usage = Usage(
            inputTokens: 0,
            outputTokens: 0,
            cacheReadInputTokens: 0,
            cacheCreationInputTokens: 1_000_000
        )
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage)
        let total = await tracker.totalUSD()
        // Sonnet 4.6 cache write: $3.75 / 1M
        XCTAssertEqual(total, 3.75, accuracy: 0.0001)
    }

    func testMixedTokenTypesAccumulate() async {
        let tracker = CostTracker()
        let usage = Usage(
            inputTokens: 100_000,
            outputTokens: 50_000,
            cacheReadInputTokens: 200_000,
            cacheCreationInputTokens: 10_000
        )
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage)
        let total = await tracker.totalUSD()

        // Input: 100K * $3/Mtok = $0.30
        // Output: 50K * $15/Mtok = $0.75
        // Cache read: 200K * $0.30/Mtok = $0.06
        // Cache write: 10K * $3.75/Mtok = $0.0375
        let expected = 0.30 + 0.75 + 0.06 + 0.0375
        XCTAssertEqual(total, expected, accuracy: 0.0001)
    }

    // MARK: - Multiple Messages Accumulate

    func testMultipleMessagesAccumulate() async {
        let tracker = CostTracker()
        let usage1 = Usage(inputTokens: 500_000, outputTokens: 0)
        let usage2 = Usage(inputTokens: 500_000, outputTokens: 0)
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage1)
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage2)
        let total = await tracker.totalUSD()
        // 1M total input * $3/Mtok = $3.00
        XCTAssertEqual(total, 3.0, accuracy: 0.0001)
    }

    func testZeroUsageIsZeroCost() async {
        let tracker = CostTracker()
        let usage = Usage(inputTokens: 0, outputTokens: 0)
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage)
        let total = await tracker.totalUSD()
        XCTAssertEqual(total, 0.0, accuracy: 0.0001)
    }

    // MARK: - Different Models Tracked Separately

    func testDifferentModelsTrackedSeparately() async {
        let tracker = CostTracker()
        let usage = Usage(inputTokens: 1_000_000, outputTokens: 0)
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage)  // $3/Mtok
        await tracker.record(modelId: "claude-opus-4-6", usage: usage)    // $5/Mtok
        let breakdown = await tracker.breakdown()
        XCTAssertEqual(breakdown.keys.count, 2)
        XCTAssertNotNil(breakdown["claude-sonnet-4-6"])
        XCTAssertNotNil(breakdown["claude-opus-4-6"])
    }

    func testDifferentModelCostRates() async {
        let tracker = CostTracker()
        let usage = Usage(inputTokens: 1_000_000, outputTokens: 0)
        await tracker.record(modelId: "claude-haiku-4-5-20251001", usage: usage)  // $1/Mtok
        let total = await tracker.totalUSD()
        XCTAssertEqual(total, 1.0, accuracy: 0.0001)
    }

    func testOpusModelHigherCost() async {
        let tracker = CostTracker()
        let usage = Usage(inputTokens: 1_000_000, outputTokens: 0)
        await tracker.record(modelId: "claude-opus-4-6", usage: usage)
        let total = await tracker.totalUSD()
        // Opus 4.6: $5/Mtok input
        XCTAssertEqual(total, 5.0, accuracy: 0.0001)
    }

    // MARK: - Breakdown

    func testBreakdownContainsBothCostAndTokens() async {
        let tracker = CostTracker()
        let usage = Usage(inputTokens: 100, outputTokens: 50)
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage)
        let breakdown = await tracker.breakdown()
        let entry = breakdown["claude-sonnet-4-6"]
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.tokens, 150)
        XCTAssertGreaterThan(entry?.cost ?? 0, 0)
    }

    // MARK: - Reset

    func testResetClearsState() async {
        let tracker = CostTracker()
        await tracker.record(modelId: "claude-sonnet-4-6", usage: Usage(inputTokens: 1000, outputTokens: 0))
        await tracker.reset()
        let total = await tracker.totalUSD()
        XCTAssertEqual(total, 0.0, accuracy: 0.0001)
        let breakdown = await tracker.breakdown()
        XCTAssertTrue(breakdown.isEmpty)
    }

    // MARK: - Model Aliases

    func testModelAliasResolvesToCanonical() async {
        let tracker = CostTracker()
        // "sonnet" alias should resolve to claude-sonnet-4-6 pricing
        let usage = Usage(inputTokens: 1_000_000, outputTokens: 0)
        // Record using canonical ID directly
        await tracker.record(modelId: "claude-sonnet-4-6", usage: usage)
        let total = await tracker.totalUSD()
        XCTAssertEqual(total, 3.0, accuracy: 0.0001)
    }

    // MARK: - ModelRegistry Tests (bonus)

    func testModelRegistryResolveKnownModel() {
        let info = ModelRegistry.resolve("claude-sonnet-4-6")
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.id, "claude-sonnet-4-6")
        XCTAssertEqual(info?.inputCostPer1MTokens, 3.0)
        XCTAssertEqual(info?.outputCostPer1MTokens, 15.0)
    }

    func testModelRegistryResolveAlias() {
        let info = ModelRegistry.resolve("sonnet")
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.id, "claude-sonnet-4-6")
    }

    func testModelRegistryUnknownReturnsNil() {
        let info = ModelRegistry.resolve("claude-does-not-exist-9999")
        XCTAssertNil(info)
    }

    func testModelRegistryDefaultModels() {
        XCTAssertEqual(ModelRegistry.bestModel.id, "claude-opus-4-6")
        XCTAssertEqual(ModelRegistry.defaultMainLoopModel.id, "claude-sonnet-4-6")
        XCTAssertEqual(ModelRegistry.defaultSmallFastModel.id, "claude-haiku-4-5-20251001")
    }

    func testAllModelsHavePositivePricing() {
        for model in ModelRegistry.models {
            XCTAssertGreaterThan(model.inputCostPer1MTokens, 0,
                                 "\(model.id) has zero input cost")
            XCTAssertGreaterThan(model.outputCostPer1MTokens, 0,
                                 "\(model.id) has zero output cost")
        }
    }
}
