/// FileEditTool — perform exact string replacement inside a file.
///
/// Reference: .reference/src/tools/FileEditTool/FileEditTool.ts
///
/// Behaviour mirrors the reference:
/// - Requires the file to have been previously read (ReadFileState).
/// - Fails if old_string not found.
/// - Fails if old_string is not unique and replace_all is false.
/// - When replace_all is true, replaces every occurrence.

import Foundation
import SwiftCodeCore
import SwiftCodeNative

// MARK: - FileEditTool

public struct FileEditTool: ToolHandler {
    public let name = "Edit"
    public let description = """
        Performs exact string replacements in files. The file must have been \
        read (or written) before calling Edit.
        """

    public let inputSchema = ToolInputSchema(
        properties: [
            "file_path": PropertySchema(
                type: "string",
                description: "The absolute path to the file to modify."
            ),
            "old_string": PropertySchema(
                type: "string",
                description: "The text to replace (must be unique in the file unless replace_all is true)."
            ),
            "new_string": PropertySchema(
                type: "string",
                description: "The text to replace it with."
            ),
            "replace_all": PropertySchema(
                type: "boolean",
                description: "Replace all occurrences of old_string (default false)."
            )
        ],
        required: ["file_path", "old_string", "new_string"]
    )

    private let fs: FileSystem

    public init(fs: FileSystem = .shared) {
        self.fs = fs
    }

    public func execute(input: [String: JSONValue]) async throws -> String {
        guard let path = input["file_path"]?.stringValue else {
            throw ToolError.invalidInput(tool: name, message: "file_path is required")
        }
        guard let oldString = input["old_string"]?.stringValue else {
            throw ToolError.invalidInput(tool: name, message: "old_string is required")
        }
        guard let newString = input["new_string"]?.stringValue else {
            throw ToolError.invalidInput(tool: name, message: "new_string is required")
        }
        let replaceAll = input["replace_all"]?.boolValue ?? false

        // Enforce read-before-edit contract.
        let wasRead = await ReadFileState.shared.hasBeenRead(path: path)
        if !wasRead {
            throw ToolError.fileNotRead(path: path)
        }

        let url = URL(fileURLWithPath: path)
        let contents: String
        do {
            contents = try await fs.readUTF8(at: url)
        } catch {
            throw ToolError.fileError(path: path, message: error.localizedDescription)
        }

        // Count occurrences
        let occurrences = contents.components(separatedBy: oldString).count - 1
        if occurrences == 0 {
            throw ToolError.stringNotFound(path: path, oldString: oldString)
        }
        if !replaceAll && occurrences > 1 {
            throw ToolError.stringNotUnique(path: path, count: occurrences)
        }

        // Perform replacement
        let updated: String
        if replaceAll {
            updated = contents.replacingOccurrences(of: oldString, with: newString)
        } else {
            // Replace only the first occurrence
            if let range = contents.range(of: oldString) {
                updated = contents.replacingCharacters(in: range, with: newString)
            } else {
                throw ToolError.stringNotFound(path: path, oldString: oldString)
            }
        }

        do {
            try await fs.writeUTF8(updated, to: url, createParents: false)
        } catch {
            throw ToolError.fileError(path: path, message: error.localizedDescription)
        }

        // Keep the file marked as read after editing.
        await ReadFileState.shared.markRead(path: path)

        return "The file \(path) has been edited successfully."
    }
}
