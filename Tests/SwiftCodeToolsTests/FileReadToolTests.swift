import XCTest
import SwiftCodeCore
@testable import SwiftCodeTools

final class FileReadToolTests: XCTestCase {

    let tool = FileReadTool()
    var tmpDir: URL!
    var tmpFile: URL!

    override func setUp() async throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SwiftCodeToolsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        tmpFile = tmpDir.appendingPathComponent("test.txt")
        try "line1\nline2\nline3\n".write(to: tmpFile, atomically: true, encoding: .utf8)
        // Reset read state
        await ReadFileState.shared.reset()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testReadsFullFile() async throws {
        let output = try await tool.execute(input: ["file_path": .string(tmpFile.path)])
        XCTAssertTrue(output.contains("line1"))
        XCTAssertTrue(output.contains("line2"))
        XCTAssertTrue(output.contains("line3"))
    }

    func testLineNumbersPresent() async throws {
        let output = try await tool.execute(input: ["file_path": .string(tmpFile.path)])
        XCTAssertTrue(output.contains("1\t"), "Line numbers should be present")
    }

    func testOffsetLimit() async throws {
        let output = try await tool.execute(input: [
            "file_path": .string(tmpFile.path),
            "offset": .int(2),
            "limit": .int(1)
        ])
        XCTAssertTrue(output.contains("line2"), "Offset 2 should start at line2")
        XCTAssertFalse(output.contains("line1"), "Should not contain line1 with offset 2")
    }

    func testMarksFileAsRead() async throws {
        _ = try await tool.execute(input: ["file_path": .string(tmpFile.path)])
        let wasRead = await ReadFileState.shared.hasBeenRead(path: tmpFile.path)
        XCTAssertTrue(wasRead, "File should be marked as read after FileReadTool call")
    }

    func testMissingPathThrows() async {
        do {
            _ = try await tool.execute(input: [:])
            XCTFail("Should throw")
        } catch ToolError.invalidInput { /* expected */ }
          catch { XCTFail("Unexpected: \(error)") }
    }

    func testNonexistentFileThrows() async {
        do {
            _ = try await tool.execute(input: ["file_path": .string("/nonexistent/path/xyz.txt")])
            XCTFail("Should throw")
        } catch ToolError.fileError { /* expected */ }
          catch { XCTFail("Unexpected: \(error)") }
    }

    func testToolName() {
        XCTAssertEqual(tool.name, "Read")
    }
}
