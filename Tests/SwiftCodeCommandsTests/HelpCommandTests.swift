import XCTest
@testable import SwiftCodeCommands
import SwiftCodeCore
import Foundation

final class HelpCommandTests: XCTestCase {
    let ctx = SlashCommandContext()

    func testHelpReturnsMessage() async throws {
        let cmd = HelpCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .message(let text) = result else {
            return XCTFail("Expected .message result")
        }
        XCTAssertTrue(text.contains("Available slash commands:"))
    }

    func testHelpListsVimCommand() async throws {
        let cmd = HelpCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .message(let text) = result else { return XCTFail() }
        XCTAssertTrue(text.contains("/vim"), "Help should list /vim")
    }

    func testHelpListsHelpItself() async throws {
        let cmd = HelpCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .message(let text) = result else { return XCTFail() }
        XCTAssertTrue(text.contains("/help"), "Help should list /help")
    }

    func testHelpDoesNotListAntOnlyForExternalUser() async throws {
        let cmd = HelpCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .message(let text) = result else { return XCTFail() }
        XCTAssertFalse(text.contains("/ant-trace"), "ant-trace should be hidden for external users")
    }
}
