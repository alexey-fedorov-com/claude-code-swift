/// Common result types for tool execution.
///
/// Reference: .reference/src/Tool.ts (ToolResult, ToolError)

import Foundation
import SwiftCodeCore

// MARK: - ToolError

/// Errors that tools can throw.
public enum ToolError: Error, Sendable {
    /// The tool has not been implemented yet. plannedTask indicates which task will implement it.
    case notImplemented(tool: String, plannedTask: Int)
    /// A required parameter was missing or had the wrong type.
    case invalidInput(tool: String, message: String)
    /// A file operation failed.
    case fileError(path: String, message: String)
    /// The string to replace was not found in the file.
    case stringNotFound(path: String, oldString: String)
    /// The string to replace is not unique (replace_all=false).
    case stringNotUnique(path: String, count: Int)
    /// The file must be read before editing.
    case fileNotRead(path: String)
    /// A subprocess exited with a non-zero code (embedded in stdout/stderr already).
    case subprocessFailed(exitCode: Int32)
    /// File exceeds the max allowed size.
    case fileTooLarge(path: String, size: Int)
}

extension ToolError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notImplemented(let tool, let task):
            return "\(tool) is not implemented in this build (planned in Task \(task))."
        case .invalidInput(let tool, let message):
            return "\(tool): invalid input — \(message)"
        case .fileError(let path, let message):
            return "File error at '\(path)': \(message)"
        case .stringNotFound(let path, let old):
            let preview = old.prefix(60)
            return "old_string not found in '\(path)': \"\(preview)\""
        case .stringNotUnique(let path, let count):
            return "old_string appears \(count) times in '\(path)'. Use replace_all: true to replace all occurrences."
        case .fileNotRead(let path):
            return "'\(path)' must be read with FileRead before editing."
        case .subprocessFailed(let code):
            return "Subprocess exited with code \(code)."
        case .fileTooLarge(let path, let size):
            let mb = size / (1024 * 1024)
            return "File '\(path)' is too large (\(mb) MB). Max allowed: 1 GiB."
        }
    }
}

// MARK: - ToolOutput

/// Structured output from a tool execution.
/// Tools return either a plain string result or an error string.
public enum ToolOutput: Sendable {
    case success(String)
    case failure(String)

    /// The string to return to the model.
    public var text: String {
        switch self {
        case .success(let t): return t
        case .failure(let t): return t
        }
    }

    public var isError: Bool {
        if case .failure = self { return true }
        return false
    }
}

// MARK: - ToolHandler

/// Protocol for all tool implementations.
/// The `execute` method receives the raw input dict and returns a string result.
public protocol ToolHandler: Sendable {
    /// Tool name sent to the API.
    var name: String { get }
    /// Human-facing description.
    var description: String { get }
    /// Input schema describing the tool's parameters.
    var inputSchema: ToolInputSchema { get }

    /// Execute the tool with the given input dictionary.
    func execute(input: [String: JSONValue]) async throws -> String
}

// MARK: - JSONValue helpers

extension JSONValue {
    /// Extracts a String value, or nil.
    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    /// Extracts an Int value, or nil.
    public var intValue: Int? {
        if case .int(let i) = self { return i }
        if case .double(let d) = self { return Int(d) }
        return nil
    }
    /// Extracts a Bool value, or nil.
    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
    /// Extracts an array, or nil.
    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
    /// Extracts an object dict, or nil.
    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
}
