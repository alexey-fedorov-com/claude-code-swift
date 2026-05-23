/// MCP tool listing and calling helpers.
///
/// Higher-level ergonomics on top of MCPClient tool methods.

import Foundation
import SwiftCodeCore

// MARK: - ToolListing

/// Helpers for listing and calling MCP tools.
public enum ToolListing {

    /// Find a tool by name.
    public static func tool(named name: String, in tools: [MCPTool]) -> MCPTool? {
        tools.first { $0.name == name }
    }

    /// Call a tool with maxResultSizeChars override (2.1.91 backport).
    ///
    /// The `_meta["anthropic/maxResultSizeChars"]` value is validated and applied.
    public static func callWithMaxSize(
        client: MCPClient,
        name: String,
        arguments: [String: JSONValue],
        maxResultSizeChars: Int? = nil
    ) async throws -> ToolCallResult {
        var meta: [String: JSONValue]? = nil
        if let max = maxResultSizeChars {
            let validated = Swift.min(Swift.max(1, max), MaxResultSize.absoluteMaxChars)
            meta = ["anthropic/maxResultSizeChars": .int(validated)]
        }
        let result = try await client.callTool(name: name, arguments: arguments, meta: meta)
        // Apply size limit if set
        if let limit = maxResultSizeChars {
            let truncated = MaxResultSize.truncate(result.content, maxChars: limit)
            return ToolCallResult(content: truncated, isError: result.isError)
        }
        return result
    }

    /// Convert tool result to a displayable string.
    public static func formatResult(_ result: ToolCallResult) -> String {
        let text = result.content.compactMap { block -> String? in
            if case .text(let t) = block { return t }
            return nil
        }.joined(separator: "\n")
        if result.isError {
            return "[ERROR] \(text)"
        }
        return text
    }
}
