/// MCP resource listing and reading helpers.
///
/// Provides higher-level ergonomics on top of MCPClient resource methods.

import Foundation
import SwiftCodeCore

// MARK: - ResourceListing

/// Helpers for listing and reading MCP resources.
public enum ResourceListing {

    /// List all resources from a server, handling pagination if supported.
    public static func listAll(client: MCPClient) async throws -> [MCPResource] {
        // Basic implementation — no cursor/pagination for now
        return try await client.listResources()
    }

    /// Read a resource and return its text content, or nil if binary.
    public static func readText(client: MCPClient, uri: String) async throws -> String? {
        let content = try await client.readResource(uri: uri)
        return content.text
    }

    /// Read a resource and return raw data for binary content.
    public static func readData(client: MCPClient, uri: String) async throws -> Data? {
        let content = try await client.readResource(uri: uri)
        return content.blob
    }

    /// Filter resources by MIME type.
    public static func resources(
        _ resources: [MCPResource],
        withMimeType mimeType: String
    ) -> [MCPResource] {
        resources.filter { $0.mimeType == mimeType }
    }

    /// Find a resource by URI.
    public static func resource(
        named uri: String,
        in resources: [MCPResource]
    ) -> MCPResource? {
        resources.first { $0.uri == uri }
    }
}
