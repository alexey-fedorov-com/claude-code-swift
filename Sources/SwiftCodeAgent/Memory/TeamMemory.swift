/// TeamMemory — shared team memory stub.
///
/// Feature flag: TEAMMEM is enabled but real sync requires backend infra.
/// TODO: implement sync with Anthropic team memory service when API is available.

import Foundation

// MARK: - TeamMemoryEntry

public struct TeamMemoryEntry: Codable, Equatable, Sendable {
    public let id: String
    public let organizationID: String
    public let key: String
    public let value: String
    public let author: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        organizationID: String,
        key: String,
        value: String,
        author: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.organizationID = organizationID
        self.key = key
        self.value = value
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - TeamMemoryError

public enum TeamMemoryError: Error, Sendable {
    /// Backend sync is not yet implemented.
    case notImplemented
    /// The team memory feature flag is disabled.
    case featureDisabled
}

// MARK: - TeamMemoryProtocol

public protocol TeamMemoryProtocol: Sendable {
    func fetch(organizationID: String) async throws -> [TeamMemoryEntry]
    func upsert(_ entry: TeamMemoryEntry) async throws
    func delete(id: String, organizationID: String) async throws
}

// MARK: - StubTeamMemory

/// Stub implementation — always throws `.notImplemented`.
/// Replace with a real HTTP client when the backend API ships.
public struct StubTeamMemory: TeamMemoryProtocol {
    public init() {}

    public func fetch(organizationID: String) async throws -> [TeamMemoryEntry] {
        // TODO: GET /v1/orgs/{organizationID}/memory
        throw TeamMemoryError.notImplemented
    }

    public func upsert(_ entry: TeamMemoryEntry) async throws {
        // TODO: PUT /v1/orgs/{organizationID}/memory/{id}
        throw TeamMemoryError.notImplemented
    }

    public func delete(id: String, organizationID: String) async throws {
        // TODO: DELETE /v1/orgs/{organizationID}/memory/{id}
        throw TeamMemoryError.notImplemented
    }
}
