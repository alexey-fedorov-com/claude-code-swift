/// Tool definition — the JSON schema shape sent to the Anthropic API for each tool.
///
/// Mirrors the TypeScript Tool interface's `inputSchema` field.
/// Reference: .reference/src/Tool.ts

import Foundation
import SwiftCodeCore

// MARK: - ToolDefinition

/// A fully-defined tool that can be serialised into the API request's `tools` array.
public struct ToolDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: ToolInputSchema

    public init(name: String, description: String, inputSchema: ToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    private enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

// MARK: - ToolInputSchema

/// A JSON-Schema object describing a tool's input parameters.
public struct ToolInputSchema: Codable, Sendable {
    public let type: String            // always "object"
    public let properties: [String: PropertySchema]
    public let required: [String]

    public init(
        properties: [String: PropertySchema],
        required: [String] = []
    ) {
        self.type = "object"
        self.properties = properties
        self.required = required
    }
}

// MARK: - PropertySchema

/// Schema for a single property inside a tool's input object.
public struct PropertySchema: Codable, Sendable {
    public let type: String
    public let description: String
    /// Possible values — used for enum-style parameters.
    public let `enum`: [String]?
    /// Nested item schema for array properties.
    public let items: PropertySchemaItems?

    public init(
        type: String,
        description: String,
        enum enumValues: [String]? = nil,
        items: PropertySchemaItems? = nil
    ) {
        self.type = type
        self.description = description
        self.enum = enumValues
        self.items = items
    }
}

// MARK: - PropertySchemaItems

/// Describes the element type of an array property.
public struct PropertySchemaItems: Codable, Sendable {
    public let type: String
    public let properties: [String: PropertySchema]?
    public let required: [String]?

    public init(
        type: String,
        properties: [String: PropertySchema]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}
