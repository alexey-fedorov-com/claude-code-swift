/// TelemetrySink — protocol + stub implementations for telemetry backends.
///
/// Real Datadog / GrowthBook / first-party sinks need API keys + network.
/// All concrete sinks here are stubs with TODO comments.
///
/// Mirrors `src/utils/telemetry.ts` sink pattern.

import Foundation

// MARK: - TelemetrySink

/// A destination for telemetry events.
public protocol TelemetrySink: Sendable {
    /// Send a single event to this sink.
    /// Implementations should swallow errors internally and log to DiagnosticLogger.
    func send(_ event: TelemetryEvent) async throws
    /// Optional: flush any buffered events.
    func flush() async throws
}

extension TelemetrySink {
    public func flush() async throws {}
}

// MARK: - DatadogSink (stub)

/// Stub — send events to Datadog RUM / logs API.
/// TODO: implement when DD_API_KEY + DD_SITE are available at runtime.
public struct DatadogSink: TelemetrySink {
    public let apiKey: String
    public let site: String   // e.g. "datadoghq.com"

    public init(apiKey: String, site: String = "datadoghq.com") {
        self.apiKey = apiKey
        self.site = site
    }

    public func send(_ event: TelemetryEvent) async throws {
        // TODO: POST https://http-intake.logs.{site}/api/v2/logs with DD-API-KEY header
    }
}

// MARK: - GrowthBookSink (stub)

/// Stub — send experiment exposure events to GrowthBook.
/// TODO: implement GrowthBook API integration.
public struct GrowthBookSink: TelemetrySink {
    public let clientKey: String

    public init(clientKey: String) {
        self.clientKey = clientKey
    }

    public func send(_ event: TelemetryEvent) async throws {
        // TODO: only forward experiment-related events to GrowthBook tracking callback
    }
}

// MARK: - FirstPartySink (stub)

/// Stub — send events to Anthropic's first-party telemetry endpoint.
/// TODO: implement when internal telemetry API contract is published.
public struct FirstPartySink: TelemetrySink {
    public let endpoint: URL

    public init(endpoint: URL) {
        self.endpoint = endpoint
    }

    public func send(_ event: TelemetryEvent) async throws {
        // TODO: POST event JSON to endpoint with session auth header
    }
}

// MARK: - NullSink

/// A no-op sink used when telemetry is disabled.
public struct NullSink: TelemetrySink {
    public init() {}
    public func send(_ event: TelemetryEvent) async throws {}
}

// MARK: - ConsoleSink (for local development)

/// Prints events to stdout — useful during development.
public struct ConsoleSink: TelemetrySink {
    public init() {}

    public func send(_ event: TelemetryEvent) async throws {
        let ts = ISO8601DateFormatter().string(from: event.timestamp)
        print("[telemetry] \(ts) \(event.name)")
    }
}
