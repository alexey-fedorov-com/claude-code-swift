/// Permission mode types and display metadata.
///
/// Mirrors the TypeScript reference at src/utils/permissions/PermissionMode.ts
/// and src/types/permissions.ts.
///
/// Note: `auto` and `bubble` are gated behind the TRANSCRIPT_CLASSIFIER feature
/// flag, which is always `false` in our build (see shims/bun-bundle.ts in the
/// reference codebase). The enum cases exist for completeness but map to
/// `.default` in external surfaces.

import Foundation

// MARK: - External Permission Mode

/// Permission modes that are exposed to external surfaces (e.g., SDK).
/// Does not include `auto` or `bubble` which are Anthropic-internal.
public enum ExternalPermissionMode: String, Codable, CaseIterable, Sendable {
    case acceptEdits
    case bypassPermissions
    case `default`
    case dontAsk
    case plan
}

// MARK: - Permission Mode

/// Full set of permission modes, including internal-only ones.
/// In this build, TRANSCRIPT_CLASSIFIER = false, so `auto` and `bubble`
/// are present as enum cases but never active at runtime.
public enum PermissionMode: String, Codable, CaseIterable, Sendable {
    case acceptEdits
    case bypassPermissions
    case `default`
    case dontAsk
    case plan
    /// Gated by TRANSCRIPT_CLASSIFIER feature flag (always false in this build).
    case auto
    /// Ant-only internal mode.
    case bubble
}

// MARK: - Color Key

/// Color identifier used by the UI to style permission mode indicators.
public enum ModeColorKey: String, Sendable {
    case text
    case planMode
    case permission
    case autoAccept
    case error
    case warning
}

// MARK: - Mode Config

private struct PermissionModeConfig {
    let title: String
    let shortTitle: String
    let symbol: String
    let color: ModeColorKey
    let external: ExternalPermissionMode
}

/// The pause icon used by Plan mode (U+23F8 ⏸).
private let pauseIcon = "\u{23F8}"

private let modeConfigs: [PermissionMode: PermissionModeConfig] = [
    .default: PermissionModeConfig(
        title: "Default",
        shortTitle: "Default",
        symbol: "",
        color: .text,
        external: .default
    ),
    .plan: PermissionModeConfig(
        title: "Plan Mode",
        shortTitle: "Plan",
        symbol: pauseIcon,
        color: .planMode,
        external: .plan
    ),
    .acceptEdits: PermissionModeConfig(
        title: "Accept edits",
        shortTitle: "Accept",
        symbol: "⏵⏵",
        color: .autoAccept,
        external: .acceptEdits
    ),
    .bypassPermissions: PermissionModeConfig(
        title: "Bypass Permissions",
        shortTitle: "Bypass",
        symbol: "⏵⏵",
        color: .error,
        external: .bypassPermissions
    ),
    .dontAsk: PermissionModeConfig(
        title: "Don't Ask",
        shortTitle: "DontAsk",
        symbol: "⏵⏵",
        color: .error,
        external: .dontAsk
    ),
    // TRANSCRIPT_CLASSIFIER = false in this build, but the case exists.
    .auto: PermissionModeConfig(
        title: "Auto mode",
        shortTitle: "Auto",
        symbol: "⏵⏵",
        color: .warning,
        external: .default  // Maps to default in external surfaces
    ),
    // bubble is ant-only; maps to default externally
    .bubble: PermissionModeConfig(
        title: "Bubble",
        shortTitle: "Bubble",
        symbol: "",
        color: .text,
        external: .default
    ),
]

// MARK: - PermissionMode computed properties

extension PermissionMode {
    private var config: PermissionModeConfig {
        modeConfigs[self] ?? modeConfigs[.default]!
    }

    /// Full display title shown in the UI (e.g., "Accept edits", "Plan Mode").
    public var displayTitle: String { config.title }

    /// Compact form of the title (e.g., "Accept", "Plan").
    public var shortTitle: String { config.shortTitle }

    /// Symbol or emoji representing the mode (e.g., "⏵⏵", "⏸").
    public var symbol: String { config.symbol }

    /// Color identifier used by the UI renderer.
    public var colorKey: ModeColorKey { config.color }

    /// Maps this mode to an external-facing mode.
    /// `auto` and `bubble` both map to `.default` for external surfaces.
    public var externalMode: ExternalPermissionMode { config.external }

    /// Whether this mode is the default (no special behavior).
    public var isDefault: Bool { self == .default }

    /// Initialise from a raw string, falling back to `.default` for unknown values.
    public static func from(string: String) -> PermissionMode {
        PermissionMode(rawValue: string) ?? .default
    }

    /// Returns true if this mode is safe to expose to external (non-ant) users.
    public var isExternalMode: Bool {
        self != .auto && self != .bubble
    }
}
