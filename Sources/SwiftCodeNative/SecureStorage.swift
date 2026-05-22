/// macOS Keychain wrapper using the Security framework.
///
/// Mirrors the TypeScript reference at:
/// - src/utils/secureStorage/macOsKeychainStorage.ts
/// - src/utils/secureStorage/macOsKeychainHelpers.ts
///
/// Service name convention:
///   The reference uses `getMacOsKeychainStorageServiceName` with the suffix
///   `-credentials` giving a base service name of:
///       "Claude Code-credentials"
///   (when using the default config dir — no hash suffix appended).
///
/// This implementation wraps `SecItemAdd`, `SecItemCopyMatching`, and
/// `SecItemDelete` from the Security framework.

#if canImport(Security)
import Security
#endif
import Foundation

// MARK: - Constants

/// Matches `CREDENTIALS_SERVICE_SUFFIX` in `macOsKeychainHelpers.ts`.
public let keychainCredentialsSuffix = "-credentials"

/// Default service name used by the reference implementation when
/// `CLAUDE_CONFIG_DIR` env var is not set.
///
/// Matches `getMacOsKeychainStorageServiceName("-credentials")` without a
/// custom config dir (so no hash suffix is added).
public let defaultKeychainServiceName = "Claude Code\(keychainCredentialsSuffix)"

// MARK: - Errors

public enum SecureStorageError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case encodingError
    case itemNotFound
    case duplicateItem
}

// MARK: - SecureStorage

/// macOS Keychain wrapper.
///
/// All methods are synchronous (they call into Security framework C APIs
/// which are themselves synchronous). They are safe to call from any thread.
public struct SecureStorage: Sendable {

    public init() {}

    // MARK: Set

    /// Stores (or replaces) a secret string in the keychain.
    ///
    /// - Parameters:
    ///   - secret: The plaintext secret to store.
    ///   - account: The account name (e.g. the current username).
    ///   - service: The service name (e.g. `defaultKeychainServiceName`).
    public func setSecret(
        _ secret: String,
        account: String,
        service: String
    ) throws {
        guard let data = secret.data(using: .utf8) else {
            throw SecureStorageError.encodingError
        }

        // Try to update first; if not found, add.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist yet — add it
            var addQuery = query
            addQuery[kSecValueData as String] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw SecureStorageError.unexpectedStatus(status)
        }
    }

    // MARK: Get

    /// Retrieves a secret string from the keychain.
    ///
    /// - Returns: The stored secret, or `nil` if no item matches.
    public func getSecret(
        account: String,
        service: String
    ) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let secret = String(data: data, encoding: .utf8) else {
                throw SecureStorageError.encodingError
            }
            return secret
        case errSecItemNotFound:
            return nil
        default:
            throw SecureStorageError.unexpectedStatus(status)
        }
    }

    // MARK: Delete

    /// Removes the keychain entry matching `account` + `service`.
    ///
    /// Silently succeeds if the item does not exist.
    public func deleteSecret(
        account: String,
        service: String
    ) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.unexpectedStatus(status)
        }
    }
}

// MARK: - Convenience

public extension SecureStorage {
    /// Returns the current username for use as the keychain account.
    ///
    /// Mirrors `getUsername()` in `macOsKeychainHelpers.ts`.
    static var currentUsername: String {
        ProcessInfo.processInfo.environment["USER"]
            ?? NSFullUserName()
    }
}
