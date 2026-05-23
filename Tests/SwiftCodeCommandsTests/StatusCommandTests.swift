import XCTest
@testable import SwiftCodeCommands
import SwiftCodeCore
import Foundation

final class StatusCommandTests: XCTestCase {

    func testStatusIncludesCwd() async throws {
        let cwd = URL(fileURLWithPath: "/tmp/test-session")
        let ctx = SlashCommandContext(workingDirectory: cwd)
        let cmd = StatusCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .message(let text) = result else {
            return XCTFail("Expected .message")
        }
        XCTAssertTrue(text.contains("/tmp/test-session"), text)
    }

    func testStatusIncludesUserType() async throws {
        let ctx = SlashCommandContext(isAntUser: false)
        let cmd = StatusCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .message(let text) = result else { return XCTFail() }
        XCTAssertTrue(text.contains("external"), text)
    }

    func testStatusIncludesAntUserLabel() async throws {
        let ctx = SlashCommandContext(isAntUser: true)
        let cmd = StatusCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .message(let text) = result else { return XCTFail() }
        XCTAssertTrue(text.contains("ant"), text)
    }

    func testStatusCommandName() {
        XCTAssertEqual(StatusCommand().name, "status")
    }
}
