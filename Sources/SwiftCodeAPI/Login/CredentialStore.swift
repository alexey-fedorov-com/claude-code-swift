import Foundation
import SwiftCodeNative

/// Persists API keys and OAuth tokens to the macOS Keychain.
///
/// Mirrors the reference's `saveCredentials` / `loadCredentials` flow in
/// services/oauth/credentials.ts. The keychain service name matches the
/// reference convention ("Claude Code-credentials").
public struct CredentialStore: Sendable {

    public enum StoredCredential: Sendable, Equatable {
        case apiKey(String)
        case oauth(OAuthToken)
    }

    private let storage: SecureStorage
    private let service: String
    private let account: String

    public init(
        storage: SecureStorage = SecureStorage(),
        service: String = defaultKeychainServiceName,
        account: String = SecureStorage.currentUsername
    ) {
        self.storage = storage
        self.service = service
        self.account = account
    }

    /// Persist a plaintext API key.
    public func saveApiKey(_ key: String) throws {
        let payload = CredentialPayload(apiKey: key, oauth: nil)
        try storage.setSecret(payload.encoded(), account: account, service: service)
    }

    /// Persist an OAuth bearer token (and its refresh metadata).
    public func saveOAuthToken(_ token: OAuthToken) throws {
        let payload = CredentialPayload(apiKey: nil, oauth: token)
        try storage.setSecret(payload.encoded(), account: account, service: service)
    }

    /// Load the currently stored credential, if any.
    public func load() throws -> StoredCredential? {
        guard let raw = try storage.getSecret(account: account, service: service) else {
            return nil
        }
        let payload = try CredentialPayload.decode(raw)
        if let token = payload.oauth { return .oauth(token) }
        if let key = payload.apiKey { return .apiKey(key) }
        return nil
    }

    /// Remove the stored credential. Silently succeeds when nothing is stored.
    public func clear() throws {
        try storage.deleteSecret(account: account, service: service)
    }
}

// MARK: - Wire Format

private struct CredentialPayload: Codable {
    var apiKey: String?
    var oauth: OAuthToken?

    private enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case oauth
    }

    func encoded() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode(_ raw: String) throws -> CredentialPayload {
        guard let data = raw.data(using: .utf8) else {
            return CredentialPayload(apiKey: nil, oauth: nil)
        }
        return try JSONDecoder().decode(CredentialPayload.self, from: data)
    }
}
