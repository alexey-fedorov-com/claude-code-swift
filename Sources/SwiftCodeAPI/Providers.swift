import Foundation

// MARK: - APIProvider
// Provider detection matching the TypeScript reference: providers.ts
// Priority: BEDROCK > VERTEX > FOUNDRY > firstParty (Anthropic direct)

/// The backend API provider to use for requests.
public enum APIProvider: String, Sendable, Equatable {
    case anthropic   // First-party Anthropic API (api.anthropic.com)
    case bedrock     // AWS Bedrock
    case vertex      // Google Vertex AI
    case foundry     // Azure AI Foundry
}

// MARK: - ProviderDetector

/// Detects the active API provider from environment variables.
/// Matches the TypeScript `getAPIProvider()` in utils/model/providers.ts.
public enum ProviderDetector {

    /// Detect provider from the given environment dictionary.
    /// Defaults to `.anthropic` if no provider-specific variables are set.
    public static func detect(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> APIProvider {
        if isTruthy(env["CLAUDE_CODE_USE_BEDROCK"]) { return .bedrock }
        if isTruthy(env["CLAUDE_CODE_USE_VERTEX"])  { return .vertex  }
        if isTruthy(env["CLAUDE_CODE_USE_FOUNDRY"]) { return .foundry }
        return .anthropic
    }

    /// Returns the appropriate base URL for the detected provider.
    /// Only works for first-party Anthropic; for 3P providers the URL comes
    /// from their SDK constructors (not implemented here).
    public static func baseURL(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let override = env["ANTHROPIC_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://api.anthropic.com")!
    }

    /// Returns true if the current base URL points to a first-party Anthropic endpoint.
    public static func isFirstPartyAnthropicURL(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard let baseURL = env["ANTHROPIC_BASE_URL"] else { return true }
        guard let host = URL(string: baseURL)?.host else { return false }
        let allowed: Set<String> = ["api.anthropic.com", "api-staging.anthropic.com"]
        return allowed.contains(host)
    }

    // MARK: Private

    private static func isTruthy(_ value: String?) -> Bool {
        guard let v = value else { return false }
        let lower = v.lowercased()
        return lower == "1" || lower == "true" || lower == "yes"
    }
}
