/// OAuth/XAA authentication stub for MCP.
///
/// Some MCP servers require OAuth 2.0 authentication.
/// This is a stub — the full flow requires browser redirect handling,
/// token storage, and refresh logic which is Anthropic-internal.

import Foundation

// MARK: - OAuthToken

/// An OAuth 2.0 access token with optional refresh token.
public struct OAuthToken: Codable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let expiresAt: Date?
    public let refreshToken: String?
    public let scope: String?

    public init(
        accessToken: String,
        tokenType: String = "Bearer",
        expiresAt: Date? = nil,
        refreshToken: String? = nil,
        scope: String? = nil
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.refreshToken = refreshToken
        self.scope = scope
    }

    public var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Date() >= exp
    }
}

// MARK: - OAuthConfig

/// OAuth server configuration.
public struct OAuthConfig: Codable, Sendable {
    public let authorizationEndpoint: URL
    public let tokenEndpoint: URL
    public let clientId: String
    public let redirectURI: URL
    public let scopes: [String]

    public init(
        authorizationEndpoint: URL,
        tokenEndpoint: URL,
        clientId: String,
        redirectURI: URL,
        scopes: [String] = []
    ) {
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.scopes = scopes
    }
}

// MARK: - OAuthFlow (stub)

/// Stub OAuth 2.0 flow. Provides types; actual browser-based flow is not implemented.
public actor OAuthFlow {

    public enum OAuthError: Error, Sendable {
        case notImplemented
        case invalidState
        case tokenExpired
        case refreshFailed
    }

    private let config: OAuthConfig
    private var token: OAuthToken?

    public init(config: OAuthConfig) {
        self.config = config
    }

    /// Start the OAuth flow. Currently a stub — always throws `.notImplemented`.
    public func authorize() async throws -> OAuthToken {
        throw OAuthError.notImplemented
    }

    /// Refresh the current token. Stub.
    public func refresh() async throws -> OAuthToken {
        throw OAuthError.notImplemented
    }

    /// Return the current token, refreshing if expired.
    public func currentToken() async throws -> OAuthToken {
        guard let token else { throw OAuthError.notImplemented }
        if token.isExpired { return try await refresh() }
        return token
    }

    /// Store a token (e.g. from manual setup).
    public func setToken(_ token: OAuthToken) {
        self.token = token
    }
}
