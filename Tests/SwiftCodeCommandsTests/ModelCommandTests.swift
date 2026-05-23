import XCTest
@testable import SwiftCodeCommands
import SwiftCodeCore

final class ModelCommandTests: XCTestCase {
    let ctx = SlashCommandContext()

    func testNoArgPrintsCurrentModel() async throws {
        let cmd = ModelCommand()
        let result = try await cmd.execute(input: "", context: ctx)
        guard case .message(let text) = result else {
            return XCTFail("Expected .message")
        }
        XCTAssertTrue(text.contains("Current model:"), text)
    }

    func testValidAliasReturnsSetModel() async throws {
        let cmd = ModelCommand()
        let result = try await cmd.execute(input: "opus", context: ctx)
        guard case .setModel(let id) = result else {
            return XCTFail("Expected .setModel, got \(result)")
        }
        XCTAssertFalse(id.isEmpty)
    }

    func testValidCanonicalIdReturnsSetModel() async throws {
        let cmd = ModelCommand()
        let result = try await cmd.execute(input: "claude-sonnet-4-6", context: ctx)
        guard case .setModel(let id) = result else {
            return XCTFail("Expected .setModel, got \(result)")
        }
        XCTAssertEqual(id, "claude-sonnet-4-6")
    }

    func testUnknownModelPrintsError() async throws {
        let cmd = ModelCommand()
        let result = try await cmd.execute(input: "definitely-not-a-model", context: ctx)
        guard case .message(let text) = result else {
            return XCTFail("Expected .message for unknown model")
        }
        XCTAssertTrue(text.contains("Unknown model:"), text)
    }

    func testModelCommandName() {
        XCTAssertEqual(ModelCommand().name, "model")
    }
}
