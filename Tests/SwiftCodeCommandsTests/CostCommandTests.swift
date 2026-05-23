import XCTest
@testable import SwiftCodeCommands
import SwiftCodeCore
import SwiftCodeAPI

final class CostCommandTests: XCTestCase {

    func testCostWithNoTrackerReturnsZero() async throws {
        let ctx = SlashCommandContext(costTracker: nil)
        let cmd = CostCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .message(let text) = result else {
            return XCTFail("Expected .message")
        }
        XCTAssertTrue(text.contains("$0.00"), text)
    }

    func testCostWithTrackerShowsValue() async throws {
        let tracker = CostTracker()
        let ctx = SlashCommandContext(costTracker: tracker)
        let cmd = CostCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .message(let text) = result else {
            return XCTFail("Expected .message")
        }
        XCTAssertTrue(text.contains("Session cost:"), text)
    }

    func testCostCommandName() {
        XCTAssertEqual(CostCommand().name, "cost")
    }
}
