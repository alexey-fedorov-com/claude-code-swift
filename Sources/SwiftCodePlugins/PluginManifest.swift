/// PluginManifest — Codable manifest schema for Claude Code plugins.
///
/// Mirrors the plugin schema from .reference/src/utils/plugins/schemas.ts.
/// Plugins ship a `package.json` (or `.claude-plugin/manifest.json`) that
/// declares their capabilities.
///
/// 2.1.91 backport: `bin` field for executable PATH injection.

import Foundation
import SwiftCodeCore

// MARK: - PluginManifest

public struct PluginManifest: Codable, Sendable {
    // MARK: Required
    public var name: String
    public var version: String

    // MARK: Optional metadata
    public var description: String?
    public var author: String?
    public var license: String?
    public var homepage: String?
    public var repository: String?

    // MARK: Capabilities
    /// Hook configurations provided by this plugin.
    public var hooks: [String: [[String: JSONValue]]]?
    /// Slash commands added by this plugin.
    public var commands: [String]?
    /// Skills provided by this plugin.
    public var skills: [String]?
    /// Agents provided by this plugin.
    public var agents: [String]?
    /// Output styles provided by this plugin.
    public var outputStyles: [String]?
    /// MCP server configurations.
    public var mcpServers: [String: JSONValue]?

    // MARK: 2.1.91 backport — bin/ executables
    /// Map of command name → relative path under the plugin directory.
    /// These are prepended to PATH when executing Bash tool commands.
    public var bin: [String: String]?

    // MARK: Trust + management
    /// Trust level: "trusted" | "untrusted"
    public var trust: String?
    /// If true, plugin is managed externally (e.g. via enterprise policy).
    public var isManaged: Bool?

    // MARK: Extra fields (pass-through)
    public var extraFields: [String: JSONValue]

    // MARK: - Init

    public init(
        name: String,
        version: String,
        description: String? = nil,
        author: String? = nil,
        bin: [String: String]? = nil,
        isManaged: Bool? = nil,
        trust: String? = nil,
        extraFields: [String: JSONValue] = [:]
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.license = nil
        self.homepage = nil
        self.repository = nil
        self.hooks = nil
        self.commands = nil
        self.skills = nil
        self.agents = nil
        self.outputStyles = nil
        self.mcpServers = nil
        self.bin = bin
        self.trust = trust
        self.isManaged = isManaged
        self.extraFields = extraFields
    }

    // MARK: - Codable

    private static let knownKeys: Set<String> = [
        "name", "version", "description", "author", "license", "homepage",
        "repository", "hooks", "commands", "skills", "agents", "outputStyles",
        "mcpServers", "bin", "trust", "isManaged"
    ]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        name = try c.decode(String.self, forKey: AnyCodingKey("name"))
        version = try c.decodeIfPresent(String.self, forKey: AnyCodingKey("version")) ?? "0.0.0"
        description = try c.decodeIfPresent(String.self, forKey: AnyCodingKey("description"))
        author = try c.decodeIfPresent(String.self, forKey: AnyCodingKey("author"))
        license = try c.decodeIfPresent(String.self, forKey: AnyCodingKey("license"))
        homepage = try c.decodeIfPresent(String.self, forKey: AnyCodingKey("homepage"))
        repository = try c.decodeIfPresent(String.self, forKey: AnyCodingKey("repository"))
        hooks = try c.decodeIfPresent([String: [[String: JSONValue]]].self, forKey: AnyCodingKey("hooks"))
        commands = try c.decodeIfPresent([String].self, forKey: AnyCodingKey("commands"))
        skills = try c.decodeIfPresent([String].self, forKey: AnyCodingKey("skills"))
        agents = try c.decodeIfPresent([String].self, forKey: AnyCodingKey("agents"))
        outputStyles = try c.decodeIfPresent([String].self, forKey: AnyCodingKey("outputStyles"))
        mcpServers = try c.decodeIfPresent([String: JSONValue].self, forKey: AnyCodingKey("mcpServers"))
        bin = try c.decodeIfPresent([String: String].self, forKey: AnyCodingKey("bin"))
        trust = try c.decodeIfPresent(String.self, forKey: AnyCodingKey("trust"))
        isManaged = try c.decodeIfPresent(Bool.self, forKey: AnyCodingKey("isManaged"))

        var extra: [String: JSONValue] = [:]
        for key in c.allKeys where !Self.knownKeys.contains(key.stringValue) {
            extra[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }
        extraFields = extra
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyCodingKey.self)
        try c.encode(name, forKey: AnyCodingKey("name"))
        try c.encode(version, forKey: AnyCodingKey("version"))
        try c.encodeIfPresent(description, forKey: AnyCodingKey("description"))
        try c.encodeIfPresent(author, forKey: AnyCodingKey("author"))
        try c.encodeIfPresent(license, forKey: AnyCodingKey("license"))
        try c.encodeIfPresent(homepage, forKey: AnyCodingKey("homepage"))
        try c.encodeIfPresent(repository, forKey: AnyCodingKey("repository"))
        try c.encodeIfPresent(hooks, forKey: AnyCodingKey("hooks"))
        try c.encodeIfPresent(commands, forKey: AnyCodingKey("commands"))
        try c.encodeIfPresent(skills, forKey: AnyCodingKey("skills"))
        try c.encodeIfPresent(agents, forKey: AnyCodingKey("agents"))
        try c.encodeIfPresent(outputStyles, forKey: AnyCodingKey("outputStyles"))
        try c.encodeIfPresent(mcpServers, forKey: AnyCodingKey("mcpServers"))
        try c.encodeIfPresent(bin, forKey: AnyCodingKey("bin"))
        try c.encodeIfPresent(trust, forKey: AnyCodingKey("trust"))
        try c.encodeIfPresent(isManaged, forKey: AnyCodingKey("isManaged"))
        for (key, value) in extraFields {
            try c.encode(value, forKey: AnyCodingKey(key))
        }
    }
}

// MARK: - Manifest validation

extension PluginManifest {
    /// Validates required fields and basic constraints.
    public func validate() throws {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            throw PluginManifestError.emptyName
        }

        // Name must be a valid npm-style identifier
        let validName = name.allSatisfy { c in
            c.isLetter || c.isNumber || c == "-" || c == "_" || c == "." || c == "@" || c == "/"
        }
        if !validName {
            throw PluginManifestError.invalidName(name)
        }

        if version.trimmingCharacters(in: .whitespaces).isEmpty {
            throw PluginManifestError.emptyVersion
        }

        // Trust field must be one of the known values if present
        if let trust {
            let validTrust: Set<String> = ["trusted", "untrusted"]
            if !validTrust.contains(trust) {
                throw PluginManifestError.invalidTrust(trust)
            }
        }
    }
}

// MARK: - PluginManifestError

public enum PluginManifestError: Error, LocalizedError, Equatable {
    case emptyName
    case invalidName(String)
    case emptyVersion
    case invalidTrust(String)
    case missingManifestFile(URL)
    case decodingFailed(String)  // Error description string (Error is not Equatable)

    public static func decodingFailed(_ error: Error) -> PluginManifestError {
        .decodingFailed(error.localizedDescription)
    }

    public var errorDescription: String? {
        switch self {
        case .emptyName:               return "Plugin manifest 'name' field is empty"
        case .invalidName(let n):      return "Plugin manifest has invalid name '\(n)'"
        case .emptyVersion:            return "Plugin manifest 'version' field is empty"
        case .invalidTrust(let t):     return "Plugin manifest 'trust' must be 'trusted' or 'untrusted', got '\(t)'"
        case .missingManifestFile(let u): return "Plugin manifest not found at \(u.path)"
        case .decodingFailed(let msg): return "Plugin manifest decoding failed: \(msg)"
        }
    }
}

// MARK: - AnyCodingKey

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
