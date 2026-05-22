import XCTest
import SwiftCodeCore
@testable import SwiftCodeTools

final class FileEditToolTests: XCTestCase {

    let tool = FileEditTool()
    var tmpDir: URL!
    var tmpFile: URL!

    override func setUp() async throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SwiftCodeToolsEditTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        tmpFile = tmpDir.appendingPathComponent("edit.txt")
        try "hello world\n".write(to: tmpFile, atomically: true, encoding: .utf8)
        await ReadFileState.shared.reset()
        // Mark as read so editing is allowed
        await ReadFileState.shared.markRead(path: tmpFile.path)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testBasicReplacement() async throws {
        _ = try await tool.execute(input: [
            "file_path": .string(tmpFile.path),
            "old_string": .string("hello"),
            "new_string": .string("goodbye")
        ])
        let content = try String(contentsOf: tmpFile, encoding: .utf8)
        XCTAssertEqual(content, "goodbye world\n")
    }

    func testStringNotFoundThrows() async {
        do {
            _ = try await tool.execute(input: [
                "file_path": .string(tmpFile.path),
                "old_string": .string("nothere"),
                "new_string": .string("x")
            ])
            XCTFail("Should throw stringNotFound")
        } catch ToolError.stringNotFound { /* expected */ }
          catch { XCTFail("Unexpected: \(error)") }
    }

    func testDuplicateStringThrows() async throws {
        // Write file with duplicate occurrence
        try "abc abc\n".write(to: tmpFile, atomically: true, encoding: .utf8)
        do {
            _ = try await tool.execute(input: [
                "file_path": .string(tmpFile.path),
                "old_string": .string("abc"),
                "new_string": .string("xyz")
            ])
            XCTFail("Should throw stringNotUnique")
        } catch ToolError.stringNotUnique { /* expected */ }
          catch { XCTFail("Unexpected: \(error)") }
    }

    func testReplaceAll() async throws {
        try "abc abc abc\n".write(to: tmpFile, atomically: true, encoding: .utf8)
        _ = try await tool.execute(input: [
            "file_path": .string(tmpFile.path),
            "old_string": .string("abc"),
            "new_string": .string("xyz"),
            "replace_all": .bool(true)
        ])
        let content = try String(contentsOf: tmpFile, encoding: .utf8)
        XCTAssertEqual(content, "xyz xyz xyz\n")
    }

    func testFileNotReadThrows() async {
        await ReadFileState.shared.reset()
        do {
            _ = try await tool.execute(input: [
                "file_path": .string(tmpFile.path),
                "old_string": .string("hello"),
                "new_string": .string("bye")
            ])
            XCTFail("Should throw fileNotRead")
        } catch ToolError.fileNotRead { /* expected */ }
          catch { XCTFail("Unexpected: \(error)") }
    }

    func testToolName() {
        XCTAssertEqual(tool.name, "Edit")
    }
}
