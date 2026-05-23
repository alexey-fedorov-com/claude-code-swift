/// Multi-element error content block handling (2.1.89 backport).
///
/// MCP tool errors can contain multiple content blocks.
/// Prior to 2.1.89, only the first block was used.
/// This module provides helpers for working with full error content.

import Foundation

// MARK: - ErrorContent

public enum ErrorContent {

    /// Extract all text from an error tool result (never truncated to first block).
    ///
    /// 2.1.89 backport: preserve ALL content blocks in error results.
    public static func allText(from result: ToolCallResult) -> String {
        result.content.compactMap { block -> String? in
            if case .text(let t) = block { return t }
            return nil
        }.joined(separator: "\n")
    }

    /// Build an error ToolCallResult preserving all content blocks.
    public static func makeError(blocks: [MCPContentBlock]) -> ToolCallResult {
        ToolCallResult(content: blocks, isError: true)
    }

    /// Build a simple text error ToolCallResult.
    public static func makeError(message: String) -> ToolCallResult {
        ToolCallResult(content: [.text(message)], isError: true)
    }

    /// Combine multiple error messages into a single result (all blocks preserved).
    public static func combine(_ results: [ToolCallResult]) -> ToolCallResult {
        let allBlocks = results.flatMap { $0.content }
        let anyError = results.contains { $0.isError }
        return ToolCallResult(content: allBlocks, isError: anyError)
    }
}
