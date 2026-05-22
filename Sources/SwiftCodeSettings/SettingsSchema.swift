/// SettingsSchema — Codable struct for the settings.json shape.
///
/// Mirrors `SettingsSchema` from `src/utils/settings/types.ts`.
///
/// Design decisions:
/// - Only typed fields the plan requires + a `[String: JSONValue]` catch-all.
/// - Custom init(from:)/encode(to:) preserve unknown fields on round-trip.
/// - validate() throws SettingsValidationError for bad values.

import Foundation
import SwiftCodeCore

// MARK: - Validation Errors

public enum SettingsValidationError: Error, LocalizedError {
    case cleanupPeriodDaysZero
    case invalidDefaultMode(String)
    case custom(String)

    public var errorDescription: String? {
        switch self {
        case .cleanupPeriodDaysZero:
            return "cleanupPeriodDays must be greater than 0. Use --no-session-persistence to disable session persistence instead."
        case .invalidDefaultMode(let mode):
            return "permissions.defaultMode '\(mode)' is not enabled in this build. TRANSCRIPT_CLASSIFIER is disabled; valid modes are: default, acceptEdits, bypassPermissions, dontAsk, plan."
        case .custom(let msg):
            return msg
        }
    }
}

// MARK: - Permissions Sub-schema

/// Valid `defaultMode` values when TRANSCRIPT_CLASSIFIER feature flag is disabled.
/// `auto` is ant-only (requires TRANSCRIPT_CLASSIFIER=true) and never valid here.
public let externalPermissionModes: Set<String> = [
    "default", "acceptEdits", "bypassPermissions", "dontAsk", "plan"
]

public struct PermissionsSettings: Codable, Sendable {
    public var allow: [String]?
    public var deny: [String]?
    public var ask: [String]?
    public var defaultMode: String?
    public var disableBypassPermissionsMode: String?   // enum: "disable"
    public var additionalDirectories: [String]?

    // Extra fields within permissions (passthrough)
    public var extraFields: [String: JSONValue]

    public init(
        allow: [String]? = nil,
        deny: [String]? = nil,
        ask: [String]? = nil,
        defaultMode: String? = nil,
        disableBypassPermissionsMode: String? = nil,
        additionalDirectories: [String]? = nil
    ) {
        self.allow = allow
        self.deny = deny
        self.ask = ask
        self.defaultMode = defaultMode
        self.disableBypassPermissionsMode = disableBypassPermissionsMode
        self.additionalDirectories = additionalDirectories
        self.extraFields = [:]
    }

    private enum KnownKey: String, CodingKey {
        case allow, deny, ask, defaultMode
        case disableBypassPermissionsMode
        case additionalDirectories
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        allow = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("allow"))
        deny = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("deny"))
        ask = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("ask"))
        defaultMode = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("defaultMode"))
        disableBypassPermissionsMode = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("disableBypassPermissionsMode"))
        additionalDirectories = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("additionalDirectories"))

        let known: Set<String> = ["allow","deny","ask","defaultMode","disableBypassPermissionsMode","additionalDirectories"]
        var extra: [String: JSONValue] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) {
            extra[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        extraFields = extra
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encodeIfPresent(allow, forKey: AnyCodingKey("allow"))
        try container.encodeIfPresent(deny, forKey: AnyCodingKey("deny"))
        try container.encodeIfPresent(ask, forKey: AnyCodingKey("ask"))
        try container.encodeIfPresent(defaultMode, forKey: AnyCodingKey("defaultMode"))
        try container.encodeIfPresent(disableBypassPermissionsMode, forKey: AnyCodingKey("disableBypassPermissionsMode"))
        try container.encodeIfPresent(additionalDirectories, forKey: AnyCodingKey("additionalDirectories"))
        for (key, value) in extraFields {
            try container.encode(value, forKey: AnyCodingKey(key))
        }
    }
}

// MARK: - SettingsSchema

/// Top-level settings.json schema.
/// Fields match the reference TypeScript `SettingsSchema` / `SettingsJson` type.
/// Unknown top-level keys are captured in `extraFields` and round-tripped verbatim.
public struct SettingsSchema: Codable, Sendable {

    // MARK: Known Fields

    public var schema: String?                          // "$schema"
    public var apiKeyHelper: String?
    public var awsCredentialExport: String?
    public var awsAuthRefresh: String?
    public var gcpAuthRefresh: String?
    public var model: String?
    public var theme: String?
    public var env: [String: String]?
    public var permissions: PermissionsSettings?
    public var cleanupPeriodDays: Int?
    public var disableSkillShellExecution: Bool?
    public var skipDangerousModePermissionPrompt: Bool?
    public var includeCoAuthoredBy: Bool?
    public var preferredNotifChannel: String?
    public var verbose: Bool?
    public var showThinkingSummaries: Bool?
    public var autoCompactEnabled: Bool?

    // Extra / unknown top-level fields — preserved on round-trip
    public var extraFields: [String: JSONValue]

    // MARK: - Init

    public init(
        schema: String? = nil,
        apiKeyHelper: String? = nil,
        model: String? = nil,
        theme: String? = nil,
        env: [String: String]? = nil,
        permissions: PermissionsSettings? = nil,
        cleanupPeriodDays: Int? = nil,
        disableSkillShellExecution: Bool? = nil,
        extraFields: [String: JSONValue] = [:]
    ) {
        self.schema = schema
        self.apiKeyHelper = apiKeyHelper
        self.awsCredentialExport = nil
        self.awsAuthRefresh = nil
        self.gcpAuthRefresh = nil
        self.model = model
        self.theme = theme
        self.env = env
        self.permissions = permissions
        self.cleanupPeriodDays = cleanupPeriodDays
        self.disableSkillShellExecution = disableSkillShellExecution
        self.skipDangerousModePermissionPrompt = nil
        self.includeCoAuthoredBy = nil
        self.preferredNotifChannel = nil
        self.verbose = nil
        self.showThinkingSummaries = nil
        self.autoCompactEnabled = nil
        self.extraFields = extraFields
    }

    // MARK: - Known keys for decode/encode

    private static let knownKeys: Set<String> = [
        "$schema", "apiKeyHelper", "awsCredentialExport", "awsAuthRefresh",
        "gcpAuthRefresh", "model", "theme", "env", "permissions",
        "cleanupPeriodDays", "disableSkillShellExecution",
        "skipDangerousModePermissionPrompt", "includeCoAuthoredBy",
        "preferredNotifChannel", "verbose", "showThinkingSummaries",
        "autoCompactEnabled"
    ]

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        schema = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("$schema"))
        apiKeyHelper = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("apiKeyHelper"))
        awsCredentialExport = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("awsCredentialExport"))
        awsAuthRefresh = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("awsAuthRefresh"))
        gcpAuthRefresh = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("gcpAuthRefresh"))
        model = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("model"))
        theme = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("theme"))
        env = try container.decodeIfPresent([String: String].self, forKey: AnyCodingKey("env"))
        permissions = try container.decodeIfPresent(PermissionsSettings.self, forKey: AnyCodingKey("permissions"))
        cleanupPeriodDays = try container.decodeIfPresent(Int.self, forKey: AnyCodingKey("cleanupPeriodDays"))
        disableSkillShellExecution = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("disableSkillShellExecution"))
        skipDangerousModePermissionPrompt = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("skipDangerousModePermissionPrompt"))
        includeCoAuthoredBy = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("includeCoAuthoredBy"))
        preferredNotifChannel = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("preferredNotifChannel"))
        verbose = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("verbose"))
        showThinkingSummaries = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("showThinkingSummaries"))
        autoCompactEnabled = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("autoCompactEnabled"))

        var extra: [String: JSONValue] = [:]
        for key in container.allKeys where !Self.knownKeys.contains(key.stringValue) {
            extra[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        extraFields = extra
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encodeIfPresent(schema, forKey: AnyCodingKey("$schema"))
        try container.encodeIfPresent(apiKeyHelper, forKey: AnyCodingKey("apiKeyHelper"))
        try container.encodeIfPresent(awsCredentialExport, forKey: AnyCodingKey("awsCredentialExport"))
        try container.encodeIfPresent(awsAuthRefresh, forKey: AnyCodingKey("awsAuthRefresh"))
        try container.encodeIfPresent(gcpAuthRefresh, forKey: AnyCodingKey("gcpAuthRefresh"))
        try container.encodeIfPresent(model, forKey: AnyCodingKey("model"))
        try container.encodeIfPresent(theme, forKey: AnyCodingKey("theme"))
        try container.encodeIfPresent(env, forKey: AnyCodingKey("env"))
        try container.encodeIfPresent(permissions, forKey: AnyCodingKey("permissions"))
        try container.encodeIfPresent(cleanupPeriodDays, forKey: AnyCodingKey("cleanupPeriodDays"))
        try container.encodeIfPresent(disableSkillShellExecution, forKey: AnyCodingKey("disableSkillShellExecution"))
        try container.encodeIfPresent(skipDangerousModePermissionPrompt, forKey: AnyCodingKey("skipDangerousModePermissionPrompt"))
        try container.encodeIfPresent(includeCoAuthoredBy, forKey: AnyCodingKey("includeCoAuthoredBy"))
        try container.encodeIfPresent(preferredNotifChannel, forKey: AnyCodingKey("preferredNotifChannel"))
        try container.encodeIfPresent(verbose, forKey: AnyCodingKey("verbose"))
        try container.encodeIfPresent(showThinkingSummaries, forKey: AnyCodingKey("showThinkingSummaries"))
        try container.encodeIfPresent(autoCompactEnabled, forKey: AnyCodingKey("autoCompactEnabled"))
        for (key, value) in extraFields {
            try container.encode(value, forKey: AnyCodingKey(key))
        }
    }

    // MARK: - Validation

    /// Throws `SettingsValidationError` for invalid field combinations.
    /// Mirrors the reference `cleanupPeriodDays: 0` rejection and the
    /// `permissions.defaultMode = "auto"` guard.
    public func validate() throws {
        // cleanupPeriodDays: 0 is rejected — backported from 2.1.89
        if let days = cleanupPeriodDays, days == 0 {
            throw SettingsValidationError.cleanupPeriodDaysZero
        }

        // permissions.defaultMode "auto" requires TRANSCRIPT_CLASSIFIER which is
        // always false in this build (all feature() calls return false via shim).
        if let mode = permissions?.defaultMode,
           !externalPermissionModes.contains(mode) {
            throw SettingsValidationError.invalidDefaultMode(mode)
        }
    }
}

// MARK: - AnyCodingKey helper

/// A flexible CodingKey that accepts any string — used for the extra-fields catch-all.
public struct AnyCodingKey: CodingKey {
    public var stringValue: String
    public var intValue: Int? { nil }

    public init(_ string: String) { stringValue = string }
    public init?(stringValue: String) { self.stringValue = stringValue }
    public init?(intValue: Int) { return nil }
}
