/// `_meta["anthropic/maxResultSizeChars"]` support (2.1.91 backport).
///
/// MCP tools can request up to 500K characters for large results like DB schemas.
/// Default is 50K. This is validated and capped on the client side.

import Foundation

// MARK: - MaxResultSize

/// Validates and applies maxResultSizeChars from `_meta` in MCP tool calls.
public enum MaxResultSize {

    /// Default maximum result size (50K characters).
    public static let defaultMaxChars = 50_000

    /// Absolute maximum result size (500K characters, per 2.1.91 backport).
    public static let absoluteMaxChars = 500_000

    /// Extract and validate maxResultSizeChars from `_meta`.
    ///
    /// - Parameter meta: The `_meta` dictionary from a tool call params.
    /// - Returns: The validated max size (capped at 500K, default 50K).
    public static func resolve(from meta: [String: JSONValue]?) -> Int {
        guard let meta,
              case .int(let requested) = meta["anthropic/maxResultSizeChars"] else {
            return defaultMaxChars
        }
        return min(max(1, requested), absoluteMaxChars)
    }

    /// Truncate content to the given max character limit.
    ///
    /// Truncates each text block independently.
    public static func truncate(_ blocks: [MCPContentBlock], maxChars: Int) -> [MCPContentBlock] {
        var remaining = maxChars
        return blocks.compactMap { block in
            guard remaining > 0 else { return nil }
            switch block {
            case .text(let text):
                if text.count <= remaining {
                    remaining -= text.count
                    return block
                } else {
                    let truncated = String(text.prefix(remaining))
                    remaining = 0
                    return .text(truncated + "\n[truncated]")
                }
            default:
                return block  // non-text blocks are not size-limited
            }
        }
    }
}

// Bring in JSONValue
import SwiftCodeCore
