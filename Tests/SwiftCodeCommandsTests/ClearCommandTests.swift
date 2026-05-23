import XCTest
@testable import SwiftCodeCommands
import SwiftCodeCore

final class ClearCommandTests: XCTestCase {
    let ctx = SlashCommandContext()

    func testClearReturnsClearContext() async throws {
        let cmd = ClearCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .clearContext = result else {
            return XCTFail("Expected .clearContext, got \(result)")
        }
    }

    func testClearIgnoresInput() async throws {
        let cmd = ClearCommand()
        let result = try await cmd.execute(input: "some random text", context: ctx)
        guard case .clearContext = result else {
            return XCTFail("Expected .clearContext regardless of input")
        }
    }

    func testClearCommandName() {
        XCTAssertEqual(ClearCommand().name, "clear")
    }
}
