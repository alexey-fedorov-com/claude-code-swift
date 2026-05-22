import XCTest
import SwiftCodeCore
@testable import SwiftCodeTools

final class GrepToolTests: XCTestCase {

    let tool = GrepTool()
    var tmpDir: URL!

    override func setUp() async throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SwiftCodeToolsGrepTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let f1 = tmpDir.appendingPathComponent("a.txt")
        let f2 = tmpDir.appendingPathComponent("b.txt")
        try "hello world\nfoo bar\n".write(to: f1, atomically: true, encoding: .utf8)
        try "goodbye world\nbaz qux\n".write(to: f2, atomically: true, encoding: .utf8)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testFindsPattern() async throws {
        let output = try await tool.execute(input: [
            "pattern": .string("hello"),
            "path": .string(tmpDir.path)
        ])
        XCTAssertTrue(output.contains("hello"), "Should find 'hello'")
    }

    func testFilesWithMatchesMode() async throws {
        let output = try await tool.execute(input: [
            "pattern": .string("world"),
            "path": .string(tmpDir.path),
            "output_mode": .string("files_with_matches")
        ])
        // Both files contain "world"
        XCTAssertTrue(output.contains("a.txt") || output.contains("b.txt"),
                      "files_with_matches mode should return file paths")
    }

    func testCaseInsensitive() async throws {
        let output = try await tool.execute(input: [
            "pattern": .string("HELLO"),
            "path": .string(tmpDir.path),
            "-i": .bool(true)
        ])
        XCTAssertTrue(output.contains("hello") || output.contains("a.txt"),
                      "Case-insensitive match should find 'hello'")
    }

    func testNoMatchReturnsMessage() async throws {
        let output = try await tool.execute(input: [
            "pattern": .string("zzznomatch"),
            "path": .string(tmpDir.path)
        ])
        XCTAssertTrue(output.contains("No matches found"))
    }

    func testMissingPatternThrows() async {
        do {
            _ = try await tool.execute(input: [:])
            XCTFail("Should throw")
        } catch ToolError.invalidInput { /* expected */ }
          catch { XCTFail("Unexpected: \(error)") }
    }

    func testToolName() {
        XCTAssertEqual(tool.name, "Grep")
    }
}
