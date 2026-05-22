import XCTest
import SwiftCodeCore
@testable import SwiftCodeTools

final class GlobToolTests: XCTestCase {

    let tool = GlobTool()
    var tmpDir: URL!

    override func setUp() async throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SwiftCodeToolsGlobTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        // Create test file tree
        let sub = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "".write(to: tmpDir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)
        try "".write(to: tmpDir.appendingPathComponent("b.swift"), atomically: true, encoding: .utf8)
        try "".write(to: tmpDir.appendingPathComponent("c.txt"), atomically: true, encoding: .utf8)
        try "".write(to: sub.appendingPathComponent("d.swift"), atomically: true, encoding: .utf8)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testMatchesSwiftFiles() async throws {
        let output = try await tool.execute(input: [
            "pattern": .string("*.swift"),
            "path": .string(tmpDir.path)
        ])
        XCTAssertTrue(output.contains("a.swift"), "Should match a.swift")
        XCTAssertTrue(output.contains("b.swift"), "Should match b.swift")
        XCTAssertFalse(output.contains("c.txt"), "Should not match c.txt")
    }

    func testGlobstarMatchesNested() async throws {
        let output = try await tool.execute(input: [
            "pattern": .string("**/*.swift"),
            "path": .string(tmpDir.path)
        ])
        XCTAssertTrue(output.contains("d.swift"), "Should find nested d.swift")
    }

    func testNoMatchReturnsMessage() async throws {
        let output = try await tool.execute(input: [
            "pattern": .string("*.rs"),
            "path": .string(tmpDir.path)
        ])
        XCTAssertEqual(output, "No files found")
    }

    func testMissingPatternThrows() async {
        do {
            _ = try await tool.execute(input: [:])
            XCTFail("Should throw")
        } catch ToolError.invalidInput { /* expected */ }
          catch { XCTFail("Unexpected: \(error)") }
    }

    func testToolName() {
        XCTAssertEqual(tool.name, "Glob")
    }
}
