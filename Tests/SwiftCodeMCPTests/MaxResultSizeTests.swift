import XCTest
@testable import SwiftCodeMCP
import SwiftCodeCore

/// Tests for 2.1.91 backport: `_meta["anthropic/maxResultSizeChars"]`.
final class MaxResultSizeTests: XCTestCase {

    // MARK: - MaxResultSize.resolve

    func testDefaultWhenNoMeta() {
        let size = MaxResultSize.resolve(from: nil)
        XCTAssertEqual(size, MaxResultSize.defaultMaxChars)
        XCTAssertEqual(size, 50_000)
    }

    func testDefaultWhenMetaHasNoKey() {
        let meta: [String: JSONValue] = ["other": .string("value")]
        let size = MaxResultSize.resolve(from: meta)
        XCTAssertEqual(size, MaxResultSize.defaultMaxChars)
    }

    func testCustomSize() {
        let meta: [String: JSONValue] = ["anthropic/maxResultSizeChars": .int(100_000)]
        let size = MaxResultSize.resolve(from: meta)
        XCTAssertEqual(size, 100_000)
    }

    func testClampToMaximum() {
        // Cannot exceed 500K
        let meta: [String: JSONValue] = ["anthropic/maxResultSizeChars": .int(999_999)]
        let size = MaxResultSize.resolve(from: meta)
        XCTAssertEqual(size, MaxResultSize.absoluteMaxChars)
        XCTAssertEqual(size, 500_000)
    }

    func testClampToMinimum() {
        let meta: [String: JSONValue] = ["anthropic/maxResultSizeChars": .int(0)]
        let size = MaxResultSize.resolve(from: meta)
        XCTAssertEqual(size, 1)
    }

    func testExactMaximum() {
        let meta: [String: JSONValue] = ["anthropic/maxResultSizeChars": .int(500_000)]
        let size = MaxResultSize.resolve(from: meta)
        XCTAssertEqual(size, 500_000)
    }

    // MARK: - MaxResultSize.truncate

    func testNoTruncationWhenUnderLimit() {
        let blocks: [MCPContentBlock] = [.text("Hello")]
        let result = MaxResultSize.truncate(blocks, maxChars: 100)
        XCTAssertEqual(result.count, 1)
        if case .text(let t) = result[0] { XCTAssertEqual(t, "Hello") }
    }

    func testTruncatesTextBlock() {
        let text = String(repeating: "a", count: 200)
        let blocks: [MCPContentBlock] = [.text(text)]
        let result = MaxResultSize.truncate(blocks, maxChars: 100)
        XCTAssertEqual(result.count, 1)
        if case .text(let t) = result[0] {
            XCTAssertTrue(t.hasPrefix(String(repeating: "a", count: 100)))
            XCTAssertTrue(t.hasSuffix("[truncated]"))
        }
    }

    func testMultiBlockTruncation() {
        // Block 1: 60 chars, limit 100 → passes
        // Block 2: 60 chars, only 40 remaining → truncated
        let blocks: [MCPContentBlock] = [
            .text(String(repeating: "a", count: 60)),
            .text(String(repeating: "b", count: 60))
        ]
        let result = MaxResultSize.truncate(blocks, maxChars: 100)
        XCTAssertEqual(result.count, 2)
    }

    func testImageBlockNotLimited() {
        let blocks: [MCPContentBlock] = [
            .image(mimeType: "image/png", data: String(repeating: "x", count: 1000))
        ]
        let result = MaxResultSize.truncate(blocks, maxChars: 10)
        // Image blocks pass through without size checks
        XCTAssertEqual(result.count, 1)
    }

    func testZeroRemainingDropsBlocks() {
        let blocks: [MCPContentBlock] = [
            .text(String(repeating: "a", count: 200)),
            .text("should be dropped")
        ]
        let result = MaxResultSize.truncate(blocks, maxChars: 50)
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - MCPValidation

    func testValidationPassesWithinRange() throws {
        let meta: [String: JSONValue] = ["anthropic/maxResultSizeChars": .int(100_000)]
        try MCPValidation.validateMeta(meta)  // Should not throw
    }

    func testValidationFailsAboveMax() {
        let meta: [String: JSONValue] = ["anthropic/maxResultSizeChars": .int(600_000)]
        XCTAssertThrowsError(try MCPValidation.validateMeta(meta))
    }

    func testValidationFailsBelowMin() {
        let meta: [String: JSONValue] = ["anthropic/maxResultSizeChars": .int(0)]
        XCTAssertThrowsError(try MCPValidation.validateMeta(meta))
    }

    func testValidationPassesNilMeta() throws {
        try MCPValidation.validateMeta(nil)  // Should not throw
    }
}
