import XCTest
import SwiftCodeCore
@testable import SwiftCodeTools

final class BashToolTests: XCTestCase {

    let tool = BashTool()

    func testRunsSimpleCommand() async throws {
        let output = try await tool.execute(input: ["command": .string("echo hello")])
        XCTAssertTrue(output.contains("hello"), "Expected 'hello' in output, got: \(output)")
    }

    func testCapturesStderr() async throws {
        let output = try await tool.execute(input: ["command": .string("echo err >&2")])
        XCTAssertTrue(output.contains("err"), "Expected stderr captured, got: \(output)")
    }

    func testMissingCommandThrows() async {
        do {
            _ = try await tool.execute(input: [:])
            XCTFail("Should throw ToolError.invalidInput")
        } catch ToolError.invalidInput { /* expected */ }
          catch { XCTFail("Unexpected error: \(error)") }
    }

    func testExitCodeNonZero() async throws {
        let output = try await tool.execute(input: ["command": .string("exit 1")])
        // Should return something (not crash), either empty output message or exit code
        XCTAssertFalse(output.isEmpty)
    }

    func testToolName() {
        XCTAssertEqual(tool.name, "Bash")
    }

    func testSchemaHasRequiredFields() {
        XCTAssertNotNil(tool.inputSchema.properties["command"])
        XCTAssertTrue(tool.inputSchema.required.contains("command"))
    }

    func testPwdReturnsPath() async throws {
        let output = try await tool.execute(input: ["command": .string("pwd")])
        XCTAssertTrue(output.hasPrefix("/"), "Expected absolute path, got: \(output)")
    }
}
