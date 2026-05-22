/// FileWriteTool — write content to a file, creating parent directories as needed.
///
/// Reference: .reference/src/tools/FileWriteTool/FileWriteTool.ts

import Foundation
import SwiftCodeCore
import SwiftCodeNative

// MARK: - FileWriteTool

public struct FileWriteTool: ToolHandler {
    public let name = "Write"
    public let description = """
        Writes a file to the local filesystem. NEVER proactively create documentation \
        files or README files unless explicitly requested.
        """

    public let inputSchema = ToolInputSchema(
        properties: [
            "file_path": PropertySchema(
                type: "string",
                description: "The absolute path to the file to write (must be absolute, not relative)."
            ),
            "content": PropertySchema(
                type: "string",
                description: "The content to write to the file."
            )
        ],
        required: ["file_path", "content"]
    )

    private let fs: FileSystem

    public init(fs: FileSystem = .shared) {
        self.fs = fs
    }

    public func execute(input: [String: JSONValue]) async throws -> String {
        guard let path = input["file_path"]?.stringValue else {
            throw ToolError.invalidInput(tool: name, message: "file_path is required")
        }
        guard let content = input["content"]?.stringValue else {
            throw ToolError.invalidInput(tool: name, message: "content is required")
        }

        let url = URL(fileURLWithPath: path)

        do {
            try await fs.writeUTF8(content, to: url, createParents: true)
        } catch {
            throw ToolError.fileError(path: path, message: error.localizedDescription)
        }

        // Mark as read so subsequent FileEdit calls don't complain.
        await ReadFileState.shared.markRead(path: path)

        return "The file \(path) has been saved successfully."
    }
}
