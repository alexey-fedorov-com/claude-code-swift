import XCTest
import SwiftCodeCore
@testable import SwiftCodeTools

final class FileWriteToolTests: XCTestCase {

    let tool = FileWriteTool()
    var tmpDir: URL!

    override func setUp() async throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SwiftCodeToolsWriteTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        await ReadFileState.shared.reset()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testWritesNewFile() async throws {
        let dest = tmpDir.appendingPathComponent("out.txt")
        let output = try await tool.execute(input: [
            "file_path": .string(dest.path),
            "content": .string("hello world\n")
        ])
        XCTAssertTrue(output.contains("saved successfully"))
        let written = try String(contentsOf: dest, encoding: .utf8)
        XCTAssertEqual(written, "hello world\n")
    }

    func testCreatesParentDirectories() async throws {
        let nested = tmpDir.appendingPathComponent("a/b/c/file.txt")
        _ = try await tool.execute(input: [
            "file_path": .string(nested.path),
            "content": .string("nested")
        ])
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }

    func testMarksFileAsRead() async throws {
        let dest = tmpDir.appendingPathComponent("w.txt")
        _ = try await tool.execute(input: [
            "file_path": .string(dest.path),
            "content": .string("x")
        ])
        let wasRead = await ReadFileState.shared.hasBeenRead(path: dest.path)
        XCTAssertTrue(wasRead, "FileWrite should mark file as read")
    }

    func testMissingInputsThrow() async {
        do {
            _ = try await tool.execute(input: ["file_path": .string("/tmp/x.txt")])
            XCTFail("Should throw for missing content")
        } catch ToolError.invalidInput { /* expected */ }
          catch { XCTFail("Unexpected: \(error)") }
    }

    func testToolName() {
        XCTAssertEqual(tool.name, "Write")
    }
}
