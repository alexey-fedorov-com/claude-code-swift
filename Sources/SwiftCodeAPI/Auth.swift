import Foundation

// MARK: - ApiCredentials

/// Resolved credentials to attach to an outgoing request.
public struct ApiCredentials: Sendable {
    public var apiKey: String?
    public var oauthToken: OAuthToken?

    public init(apiKey: String? = nil, oauthToken: OAuthToken? = nil) {
        self.apiKey = apiKey
        self.oauthToken = oauthToken
    }
}

// MARK: - OAuthToken

/// An OAuth 2.0 bearer token plus optional refresh fields.
/// Maps to the TypeScript `OAuthTokens` type in services/oauth/types.ts.
public struct OAuthToken: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?
    public var tokenType: String?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        tokenType: String? = "Bearer"
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
    }

    /// True if the token has a known expiry and it is in the past.
    public var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return expiry <= Date()
    }
}

// MARK: - AuthSource

/// Describes where credentials were obtained from.
public enum AuthSource: Sendable {
    case env(String)               // Environment variable name, e.g. "ANTHROPIC_API_KEY"
    case keychain(String)          // Keychain service name
    case apiKeyHelper(URL)         // Path to external helper script
    case oauth(OAuthToken)         // OAuth bearer token
}

// MARK: - OAuth Constants
// Matching constants from constants/oauth.ts

public enum OAuthConstants {
    public static let clientID       = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    public static let tokenURL       = "https://platform.claude.com/v1/oauth/token"
    public static let apiKeyURL      = "https://api.anthropic.com/api/oauth/claude_cli/create_api_key"
    public static let baseAPIURL     = "https://api.anthropic.com"
    public static let authorizeURL   = "https://claude.com/cai/oauth/authorize"
    public static let oauthBetaHeader = "oauth-2025-04-20"

    public static let scopes: [String] = [
        "user:profile",
        "user:inference",
        "user:sessions:claude_code",
        "user:mcp_servers",
        "user:file_upload",
        "org:create_api_key",
    ]
}

// MARK: - AuthProvider Protocol

/// Provides credentials on demand. Implementations may be async (e.g. keychain, token refresh).
public protocol AuthProvider: Sendable {
    func credentials() async throws -> ApiCredentials
}

// MARK: - EnvAuthProvider

/// Reads the API key from an environment variable (default: ANTHROPIC_API_KEY).
/// Also supports ANTHROPIC_AUTH_TOKEN as a fallback bearer token.
public struct EnvAuthProvider: AuthProvider {
    private let envVarName: String
    private let env: [String: String]

    public init(
        envVarName: String = "ANTHROPIC_API_KEY",
        env: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.envVarName = envVarName
        self.env = env
    }

    public func credentials() async throws -> ApiCredentials {
        if let key = env[envVarName], !key.isEmpty {
            return ApiCredentials(apiKey: key)
        }
        // ANTHROPIC_AUTH_TOKEN is used as a bearer / OAuth-style token
        if let token = env["ANTHROPIC_AUTH_TOKEN"], !token.isEmpty {
            let oauth = OAuthToken(accessToken: token)
            return ApiCredentials(oauthToken: oauth)
        }
        return ApiCredentials()
    }
}

// MARK: - KeychainAuthProvider (Stub)

/// Reads an API key or OAuth token from the macOS Keychain.
/// The actual implementation defers to SwiftCodeNative.SecureStorage.
/// TODO: Wire up real keychain access when SwiftCodeNative is available.
public struct KeychainAuthProvider: AuthProvider {
    private let serviceName: String

    public init(serviceName: String = "com.anthropic.claude-code") {
        self.serviceName = serviceName
    }

    public func credentials() async throws -> ApiCredentials {
        // TODO: implement via SwiftCodeNative.SecureStorage
        // For now, fall through to env-based auth.
        return ApiCredentials()
    }
}

// MARK: - ApiKeyHelperProvider (Stub)

/// Invokes an external helper script to obtain an API key.
/// Matches the TypeScript `getApiKeyFromApiKeyHelper` flow in utils/auth.ts.
/// TODO: implement process execution via SwiftCodeNative.ProcessRunner.
public struct ApiKeyHelperProvider: AuthProvider {
    private let helperURL: URL

    public init(helperURL: URL) {
        self.helperURL = helperURL
    }

    public func credentials() async throws -> ApiCredentials {
        // TODO: spawn helperURL and parse stdout as an API key
        throw AuthError.notImplemented("ApiKeyHelper requires process execution support")
    }
}

// MARK: - CompositeAuthProvider

/// Tries multiple providers in order and returns the first non-empty credentials.
public struct CompositeAuthProvider: AuthProvider {
    private let providers: [any AuthProvider]

    public init(providers: [any AuthProvider]) {
        self.providers = providers
    }

    /// Convenience: default provider chain that mirrors the reference auth flow.
    public static func makeDefault(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> CompositeAuthProvider {
        var providers: [any AuthProvider] = [
            EnvAuthProvider(envVarName: "ANTHROPIC_API_KEY", env: env),
        ]
        // If the user has set ANTHROPIC_AUTH_TOKEN but not ANTHROPIC_API_KEY,
        // EnvAuthProvider still handles it in its fallback branch.
        providers.append(KeychainAuthProvider())
        return CompositeAuthProvider(providers: providers)
    }

    public func credentials() async throws -> ApiCredentials {
        for provider in providers {
            let creds = try await provider.credentials()
            if creds.apiKey != nil || creds.oauthToken != nil {
                return creds
            }
        }
        return ApiCredentials()
    }
}

// MARK: - AuthError

public enum AuthError: Error, Sendable {
    case noCredentials
    case tokenExpired
    case notImplemented(String)
}

// MARK: - OAuthFlowStub
// The full OAuth browser callback flow (PKCE, local redirect server) is deferred.
// Types and protocol surface exist; actual network/browser calls are TODO.

/// Represents the state of an in-flight OAuth authorization.
public struct OAuthFlowState: Sendable {
    public let authorizeURL: URL
    public let codeVerifier: String    // PKCE
    public let state: String           // CSRF
}

/// Protocol for OAuth flow implementations.
/// TODO: implement in SwiftCodeMCP / SwiftCodeRemote where browser launch is available.
public protocol OAuthFlow: Sendable {
    func beginAuthorization() async throws -> OAuthFlowState
    func exchangeCode(_ code: String, state: OAuthFlowState) async throws -> OAuthToken
    func refresh(_ token: OAuthToken) async throws -> OAuthToken
}
