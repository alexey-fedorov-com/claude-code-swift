import XCTest
@testable import SwiftCodeCommands
import SwiftCodeCore

final class VimCommandTests: XCTestCase {
    let ctx = SlashCommandContext()

    func testVimReturnsPromptInjectionWithSentinel() async throws {
        let cmd = VimCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .promptInjection(let sentinel) = result else {
            return XCTFail("Expected .promptInjection, got \(result)")
        }
        XCTAssertEqual(sentinel, VimCommand.toggleSentinel)
    }

    func testVimCommandName() {
        XCTAssertEqual(VimCommand().name, "vim")
    }

    func testVimToggleSentinel() {
        XCTAssertEqual(VimCommand.toggleSentinel, "__VIM_TOGGLE__")
    }
}
