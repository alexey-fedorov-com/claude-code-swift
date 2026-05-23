import XCTest
@testable import SwiftCodeMCP

/// Tests for 2.1.89 backport: `MCP_CONNECTION_NONBLOCKING=true` 5s timeout.
final class NonblockingConnectionTests: XCTestCase {

    func testDefaultTimeout() {
        // Without env var, default should be 30s
        // Note: we can't modify ProcessInfo.processInfo.environment in tests,
        // so we test the static values directly.
        XCTAssertEqual(NonblockingConnection.defaultTimeout, 30.0)
        XCTAssertEqual(NonblockingConnection.nonblockingTimeout, 5.0)
    }

    func testNonblockingIsLessThanDefault() {
        XCTAssertLessThan(
            NonblockingConnection.nonblockingTimeout,
            NonblockingConnection.defaultTimeout
        )
    }

    func testWithTimeoutSucceeds() async throws {
        // Should complete quickly
        let result = try await NonblockingConnection.withTimeout(1.0) {
            return "done"
        }
        XCTAssertEqual(result, "done")
    }

    func testWithTimeoutThrowsOnExpiry() async {
        do {
            _ = try await NonblockingConnection.withTimeout(0.05) {
                // Sleep longer than the timeout
                try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
                return "too slow"
            }
            XCTFail("Should have thrown timeout error")
        } catch {
            // Expected: TransportError.timeout
            if let te = error as? TransportError, case .timeout = te {
                // Correct
            } else {
                // Other errors (like cancellation) are also acceptable
            }
        }
    }

    func testWithTimeoutNilUsesDefault() async throws {
        // When nil, uses connectionTimeout (which varies by env var)
        // Just verify it succeeds for a fast operation
        let result = try await NonblockingConnection.withTimeout(nil) {
            return 42
        }
        XCTAssertEqual(result, 42)
    }

    func testConnectionTimeoutIsOneOfKnownValues() {
        let timeout = NonblockingConnection.connectionTimeout
        let valid = [NonblockingConnection.defaultTimeout, NonblockingConnection.nonblockingTimeout]
        XCTAssertTrue(valid.contains(timeout), "Timeout should be 5 or 30 seconds, got \(timeout)")
    }

    // MARK: - ErrorContent (2.1.89 backport)

    func testErrorContentAllText() {
        let result = ToolCallResult(
            content: [
                .text("Error: first block"),
                .text("Error: second block"),
                .text("Error: third block")
            ],
            isError: true
        )
        let text = ErrorContent.allText(from: result)
        XCTAssertTrue(text.contains("first block"))
        XCTAssertTrue(text.contains("second block"))
        XCTAssertTrue(text.contains("third block"))
    }

    func testErrorContentMakeError() {
        let result = ErrorContent.makeError(message: "Something went wrong")
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.content.count, 1)
        if case .text(let t) = result.content[0] {
            XCTAssertEqual(t, "Something went wrong")
        } else {
            XCTFail("Expected text block")
        }
    }

    func testErrorContentCombinePreservesAllBlocks() {
        let r1 = ToolCallResult(content: [.text("block 1"), .text("block 2")], isError: true)
        let r2 = ToolCallResult(content: [.text("block 3")], isError: false)
        let combined = ErrorContent.combine([r1, r2])
        XCTAssertEqual(combined.content.count, 3)
        XCTAssertTrue(combined.isError)  // any error → error
    }

    func testErrorContentMakeErrorBlocks() {
        let blocks: [MCPContentBlock] = [
            .text("line 1"),
            .text("line 2"),
            .image(mimeType: "image/png", data: "data")
        ]
        let result = ErrorContent.makeError(blocks: blocks)
        XCTAssertEqual(result.content.count, 3)
        XCTAssertTrue(result.isError)
    }
}
