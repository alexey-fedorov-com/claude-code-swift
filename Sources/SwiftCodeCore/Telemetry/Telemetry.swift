/// Telemetry — main client with opt-out gating and privacy level enforcement.
///
/// Opt-out env vars (any one disables all telemetry):
///   CLAUDE_CODE_TELEMETRY=0
///   DISABLE_TELEMETRY=1
///   OTEL_SDK_DISABLED=true
///
/// Privacy level env var: CLAUDE_CODE_TELEMETRY_LEVEL=off|minimal|full
///
/// Mirrors `src/utils/log.ts` and `src/utils/telemetry.ts`.

import Foundation

// MARK: - Telemetry

public actor Telemetry {
    // MARK: - State

    private let sinks: [TelemetrySink]
    private let env: [String: String]
    private var _privacyLevel: PrivacyLevel?

    // MARK: - Init

    public init(
        sinks: [TelemetrySink] = [],
        env: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.sinks = sinks
        self.env = env
    }

    // MARK: - Opt-out gating

    /// Returns true if telemetry collection is active.
    ///
    /// Returns false if any of the following is set:
    ///   - `CLAUDE_CODE_TELEMETRY` = "0" or "false"
    ///   - `DISABLE_TELEMETRY` = "1" or "true"
    ///   - `OTEL_SDK_DISABLED` = "true"
    public func isEnabled() -> Bool {
        // CLAUDE_CODE_TELEMETRY=0
        if let val = env["CLAUDE_CODE_TELEMETRY"], isDisableValue(val) { return false }
        // DISABLE_TELEMETRY=1
        if let val = env["DISABLE_TELEMETRY"], isEnableValue(val) { return false }
        // OTEL_SDK_DISABLED=true
        if let val = env["OTEL_SDK_DISABLED"], val.lowercased() == "true" { return false }
        return true
    }

    // MARK: - Privacy level

    /// Effective privacy level. Reads `CLAUDE_CODE_TELEMETRY_LEVEL` env var.
    public func privacyLevel() -> PrivacyLevel {
        if let cached = _privacyLevel { return cached }
        let level = resolvePrivacyLevel()
        _privacyLevel = level
        return level
    }

    // MARK: - Emit

    /// Emit an event to all sinks, respecting opt-out and privacy level.
    public func emit(_ event: TelemetryEvent) async {
        guard isEnabled() else { return }
        let level = privacyLevel()
        guard level != .off else { return }
        // Drop events that require a higher privacy level than configured
        guard event.privacyLevel <= level else { return }

        await withTaskGroup(of: Void.self) { group in
            for sink in sinks {
                group.addTask {
                    try? await sink.send(event)
                }
            }
        }
    }

    /// Flush all buffered events in all sinks.
    public func flush() async {
        for sink in sinks {
            try? await sink.flush()
        }
    }

    // MARK: - Private helpers

    private func resolvePrivacyLevel() -> PrivacyLevel {
        guard isEnabled() else { return .off }
        if let raw = env["CLAUDE_CODE_TELEMETRY_LEVEL"],
           let level = PrivacyLevel(rawValue: raw.lowercased()) {
            return level
        }
        return .full   // default
    }

    private func isDisableValue(_ s: String) -> Bool {
        s == "0" || s.lowercased() == "false"
    }

    private func isEnableValue(_ s: String) -> Bool {
        s == "1" || s.lowercased() == "true"
    }
}

// MARK: - Shared instance

extension Telemetry {
    /// A shared instance using only the console sink (for development).
    /// Production code should inject real sinks at startup.
    public static let shared = Telemetry(sinks: [])
}
