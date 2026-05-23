import XCTest
@testable import SwiftCodeCommands
import SwiftCodeCore

final class ExitCommandTests: XCTestCase {
    let ctx = SlashCommandContext()

    func testExitReturnsExitZero() async throws {
        let cmd = ExitCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .exit(let code) = result else {
            return XCTFail("Expected .exit, got \(result)")
        }
        XCTAssertEqual(code, 0)
    }

    func testExitHasQuitAlias() {
        XCTAssertTrue(ExitCommand().aliases.contains("quit"))
    }

    func testExitCommandName() {
        XCTAssertEqual(ExitCommand().name, "exit")
    }
}
