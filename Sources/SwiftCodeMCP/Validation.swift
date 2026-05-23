/// MCP parameter validation utilities.
///
/// Validates `_meta["anthropic/maxResultSizeChars"]` and other params
/// per the 2.1.91 backport spec.

import Foundation
import SwiftCodeCore

// MARK: - MCPValidation

public enum MCPValidation {

    public enum ValidationError: Error, Sendable {
        case maxResultSizeOutOfRange(Int)
        case invalidParams(String)
    }

    /// Validate `_meta` params in a tool call.
    ///
    /// - Parameter meta: The `_meta` field from tool call params.
    /// - Throws: `ValidationError.maxResultSizeOutOfRange` if out of [1, 500_000].
    public static func validateMeta(_ meta: [String: JSONValue]?) throws {
        guard let meta,
              case .int(let requested) = meta["anthropic/maxResultSizeChars"] else {
            return
        }
        guard requested >= 1, requested <= MaxResultSize.absoluteMaxChars else {
            throw ValidationError.maxResultSizeOutOfRange(requested)
        }
    }

    /// Validate that a tool name is non-empty and contains only allowed characters.
    public static func validateToolName(_ name: String) throws {
        guard !name.isEmpty else {
            throw ValidationError.invalidParams("Tool name must not be empty")
        }
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "_-"))
        guard name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ValidationError.invalidParams("Tool name '\(name)' contains invalid characters")
        }
    }

    /// Validate a URI is non-empty.
    public static func validateURI(_ uri: String) throws {
        guard !uri.isEmpty, URL(string: uri) != nil else {
            throw ValidationError.invalidParams("Invalid URI: '\(uri)'")
        }
    }
}
