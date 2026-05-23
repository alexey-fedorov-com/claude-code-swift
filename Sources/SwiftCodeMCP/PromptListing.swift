/// MCP prompt listing and retrieval helpers.
///
/// Higher-level ergonomics on top of MCPClient prompt methods.

import Foundation

// MARK: - PromptListing

/// Helpers for listing and getting MCP prompts.
public enum PromptListing {

    /// Find a prompt by name.
    public static func prompt(named name: String, in prompts: [MCPPrompt]) -> MCPPrompt? {
        prompts.first { $0.name == name }
    }

    /// Get required arguments for a prompt.
    public static func requiredArguments(for prompt: MCPPrompt) -> [MCPPromptArgument] {
        (prompt.arguments ?? []).filter { $0.required == true }
    }

    /// Build an argument dict from a key-value list.
    public static func buildArguments(_ pairs: [(String, String)]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: pairs)
    }

    /// Extract all text content from a PromptContent as a single string.
    public static func fullText(from content: PromptContent) -> String {
        content.messages.compactMap { msg -> String? in
            if case .text(let t) = msg.content { return t }
            return nil
        }.joined(separator: "\n")
    }
}
