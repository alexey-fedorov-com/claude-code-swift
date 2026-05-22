/// ProjectConfig — per-project state stored inside `~/.claude.json` under `projects[path]`.
///
/// Mirrors `ProjectConfig` from `src/utils/config.ts`.
/// Unknown fields are preserved via `extraFields`.

import Foundation
import SwiftCodeCore

// MARK: - McpServerConfig stub (minimal — full schema is in SwiftCodeMCP)

/// Minimal MCP server config used here for project-level state.
/// The full schema lives in SwiftCodeMCP; this stub satisfies the Codable round-trip.
public struct McpServerConfigStub: Codable, Sendable {
    public var extraFields: [String: JSONValue]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        var extra: [String: JSONValue] = [:]
        for key in container.allKeys {
            extra[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        extraFields = extra
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        for (key, value) in extraFields {
            try container.encode(value, forKey: AnyCodingKey(key))
        }
    }
}

// MARK: - ProjectConfig

public struct ProjectConfig: Codable, Sendable {

    // MARK: Core fields

    public var allowedTools: [String]
    public var mcpContextUris: [String]
    public var mcpServers: [String: McpServerConfigStub]?
    public var projectOnboardingSeenCount: Int

    // MARK: Trust and onboarding

    public var hasTrustDialogAccepted: Bool?
    public var hasCompletedProjectOnboarding: Bool?
    public var hasClaudeMdExternalIncludesApproved: Bool?
    public var hasClaudeMdExternalIncludesWarningShown: Bool?

    // MARK: MCP server enablement state

    public var enabledMcpjsonServers: [String]?
    public var disabledMcpjsonServers: [String]?
    public var enableAllProjectMcpServers: Bool?
    public var disabledMcpServers: [String]?
    public var enabledMcpServers: [String]?

    // MARK: Metrics (last session)

    public var lastAPIDuration: Double?
    public var lastCost: Double?
    public var lastDuration: Double?
    public var lastSessionId: String?

    // MARK: Extra (forward-compat)

    public var extraFields: [String: JSONValue]

    // MARK: - Default

    public static let `default` = ProjectConfig(
        allowedTools: [],
        mcpContextUris: [],
        projectOnboardingSeenCount: 0,
        hasTrustDialogAccepted: false,
        hasClaudeMdExternalIncludesApproved: false,
        hasClaudeMdExternalIncludesWarningShown: false,
        enabledMcpjsonServers: [],
        disabledMcpjsonServers: []
    )

    // MARK: - Init

    public init(
        allowedTools: [String] = [],
        mcpContextUris: [String] = [],
        projectOnboardingSeenCount: Int = 0,
        hasTrustDialogAccepted: Bool? = nil,
        hasClaudeMdExternalIncludesApproved: Bool? = nil,
        hasClaudeMdExternalIncludesWarningShown: Bool? = nil,
        enabledMcpjsonServers: [String]? = nil,
        disabledMcpjsonServers: [String]? = nil
    ) {
        self.allowedTools = allowedTools
        self.mcpContextUris = mcpContextUris
        self.projectOnboardingSeenCount = projectOnboardingSeenCount
        self.hasTrustDialogAccepted = hasTrustDialogAccepted
        self.hasClaudeMdExternalIncludesApproved = hasClaudeMdExternalIncludesApproved
        self.hasClaudeMdExternalIncludesWarningShown = hasClaudeMdExternalIncludesWarningShown
        self.enabledMcpjsonServers = enabledMcpjsonServers
        self.disabledMcpjsonServers = disabledMcpjsonServers
        self.extraFields = [:]
    }

    // MARK: - Codable

    private static let knownKeys: Set<String> = [
        "allowedTools","mcpContextUris","mcpServers","projectOnboardingSeenCount",
        "hasTrustDialogAccepted","hasCompletedProjectOnboarding",
        "hasClaudeMdExternalIncludesApproved","hasClaudeMdExternalIncludesWarningShown",
        "enabledMcpjsonServers","disabledMcpjsonServers","enableAllProjectMcpServers",
        "disabledMcpServers","enabledMcpServers",
        "lastAPIDuration","lastCost","lastDuration","lastSessionId"
    ]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        allowedTools = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("allowedTools")) ?? []
        mcpContextUris = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("mcpContextUris")) ?? []
        mcpServers = try container.decodeIfPresent([String: McpServerConfigStub].self, forKey: AnyCodingKey("mcpServers"))
        projectOnboardingSeenCount = try container.decodeIfPresent(Int.self, forKey: AnyCodingKey("projectOnboardingSeenCount")) ?? 0
        hasTrustDialogAccepted = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("hasTrustDialogAccepted"))
        hasCompletedProjectOnboarding = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("hasCompletedProjectOnboarding"))
        hasClaudeMdExternalIncludesApproved = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("hasClaudeMdExternalIncludesApproved"))
        hasClaudeMdExternalIncludesWarningShown = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("hasClaudeMdExternalIncludesWarningShown"))
        enabledMcpjsonServers = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("enabledMcpjsonServers"))
        disabledMcpjsonServers = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("disabledMcpjsonServers"))
        enableAllProjectMcpServers = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("enableAllProjectMcpServers"))
        disabledMcpServers = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("disabledMcpServers"))
        enabledMcpServers = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("enabledMcpServers"))
        lastAPIDuration = try container.decodeIfPresent(Double.self, forKey: AnyCodingKey("lastAPIDuration"))
        lastCost = try container.decodeIfPresent(Double.self, forKey: AnyCodingKey("lastCost"))
        lastDuration = try container.decodeIfPresent(Double.self, forKey: AnyCodingKey("lastDuration"))
        lastSessionId = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("lastSessionId"))

        var extra: [String: JSONValue] = [:]
        for key in container.allKeys where !Self.knownKeys.contains(key.stringValue) {
            extra[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        extraFields = extra
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encode(allowedTools, forKey: AnyCodingKey("allowedTools"))
        try container.encode(mcpContextUris, forKey: AnyCodingKey("mcpContextUris"))
        try container.encodeIfPresent(mcpServers, forKey: AnyCodingKey("mcpServers"))
        try container.encode(projectOnboardingSeenCount, forKey: AnyCodingKey("projectOnboardingSeenCount"))
        try container.encodeIfPresent(hasTrustDialogAccepted, forKey: AnyCodingKey("hasTrustDialogAccepted"))
        try container.encodeIfPresent(hasCompletedProjectOnboarding, forKey: AnyCodingKey("hasCompletedProjectOnboarding"))
        try container.encodeIfPresent(hasClaudeMdExternalIncludesApproved, forKey: AnyCodingKey("hasClaudeMdExternalIncludesApproved"))
        try container.encodeIfPresent(hasClaudeMdExternalIncludesWarningShown, forKey: AnyCodingKey("hasClaudeMdExternalIncludesWarningShown"))
        try container.encodeIfPresent(enabledMcpjsonServers, forKey: AnyCodingKey("enabledMcpjsonServers"))
        try container.encodeIfPresent(disabledMcpjsonServers, forKey: AnyCodingKey("disabledMcpjsonServers"))
        try container.encodeIfPresent(enableAllProjectMcpServers, forKey: AnyCodingKey("enableAllProjectMcpServers"))
        try container.encodeIfPresent(disabledMcpServers, forKey: AnyCodingKey("disabledMcpServers"))
        try container.encodeIfPresent(enabledMcpServers, forKey: AnyCodingKey("enabledMcpServers"))
        try container.encodeIfPresent(lastAPIDuration, forKey: AnyCodingKey("lastAPIDuration"))
        try container.encodeIfPresent(lastCost, forKey: AnyCodingKey("lastCost"))
        try container.encodeIfPresent(lastDuration, forKey: AnyCodingKey("lastDuration"))
        try container.encodeIfPresent(lastSessionId, forKey: AnyCodingKey("lastSessionId"))
        for (key, value) in extraFields {
            try container.encode(value, forKey: AnyCodingKey(key))
        }
    }
}
