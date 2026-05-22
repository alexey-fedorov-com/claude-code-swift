/// FileReadTool — read a file and return its contents with line numbers.
///
/// Reference: .reference/src/tools/FileReadTool/FileReadTool.ts
/// MAX_EDIT_FILE_SIZE guard: 1 GiB (from CLAUDE.md / BashTool.tsx backport context).
/// Line-number format: "   1\thello\n" (right-aligned to match reference UI).

import Foundation
import SwiftCodeCore
import SwiftCodeNative

// MARK: - Constants

/// 1 GiB — protects against OOM when reading huge files.
private let maxEditFileSize = 1 * 1024 * 1024 * 1024

// MARK: - FileReadTool

public struct FileReadTool: ToolHandler {
    public let name = "Read"
    public let description = """
        Reads a file from the local filesystem. You can access any file directly \
        by using this tool.
        """

    public let inputSchema = ToolInputSchema(
        properties: [
            "file_path": PropertySchema(
                type: "string",
                description: "The absolute path to the file to read."
            ),
            "offset": PropertySchema(
                type: "integer",
                description: "The line number to start reading from (1-based). Only provide if the file is too large to read at once."
            ),
            "limit": PropertySchema(
                type: "integer",
                description: "The number of lines to read. Only provide if the file is too large to read at once."
            )
        ],
        required: ["file_path"]
    )

    private let fs: FileSystem

    public init(fs: FileSystem = .shared) {
        self.fs = fs
    }

    public func execute(input: [String: JSONValue]) async throws -> String {
        guard let path = input["file_path"]?.stringValue else {
            throw ToolError.invalidInput(tool: name, message: "file_path is required")
        }

        let url = URL(fileURLWithPath: path)

        // Size guard
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        if let size = attrs?[.size] as? Int, size > maxEditFileSize {
            throw ToolError.fileTooLarge(path: path, size: size)
        }

        let contents: String
        do {
            contents = try await fs.readUTF8(at: url)
        } catch {
            throw ToolError.fileError(path: path, message: error.localizedDescription)
        }

        // Mark as read so FileEditTool can edit it.
        await ReadFileState.shared.markRead(path: path)

        let lines = contents.components(separatedBy: "\n")
        let totalLines = lines.count

        // Offset is 1-based in the reference. Default to line 1.
        let offsetRaw = input["offset"]?.intValue ?? 1
        let offset = max(1, offsetRaw)
        let limit = input["limit"]?.intValue ?? totalLines

        // Slice [offset-1 ..< offset-1+limit]
        let startIdx = min(offset - 1, totalLines)
        let endIdx = min(startIdx + limit, totalLines)
        let sliced = lines[startIdx..<endIdx]

        // Format with right-aligned line numbers (pad to width of totalLines digits)
        let width = String(totalLines).count
        var result = ""
        for (i, line) in sliced.enumerated() {
            let lineNum = startIdx + i + 1
            let numStr = String(lineNum).leftPadded(toLength: width)
            result += "\(numStr)\t\(line)\n"
        }

        return result.isEmpty ? "(empty file)" : result
    }
}

// MARK: - String helper

private extension String {
    func leftPadded(toLength length: Int, with padChar: Character = " ") -> String {
        let padCount = length - self.count
        guard padCount > 0 else { return self }
        return String(repeating: padChar, count: padCount) + self
    }
}
