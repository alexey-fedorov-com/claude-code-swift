/// MarketplaceCache — keeps marketplace cache on git pull failure.
///
/// 2.1.90 backport: "CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE env var —
/// keeps existing marketplace cache when git pull fails, useful in offline environments."
///
/// Mirrors .reference/src/utils/plugins/marketplaceManager.ts (the keepOnFailure check).

import Foundation

// MARK: - MarketplaceCache

public enum MarketplaceCache {
    /// The environment variable name controlling failure behaviour.
    public static let envVarName = "CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE"

    /// Returns `true` if the marketplace cache should be preserved when a git pull fails.
    ///
    /// Controlled by the `CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE` env var.
    /// Set to "true" / "1" to keep the existing cache when git pull fails (useful offline).
    ///
    /// - Parameter env: The environment to inspect. Defaults to the current process environment.
    public static func keepOnFailure(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard let value = env[envVarName] else { return false }
        let v = value.lowercased()
        return v == "true" || v == "1" || v == "yes"
    }
}

// MARK: - Marketplace

/// A known marketplace source entry.
public struct Marketplace: Codable, Sendable, Equatable {
    /// Human-readable name for this marketplace.
    public var name: String
    /// Source URL or git repository reference.
    public var source: String
    /// Whether this is the official Anthropic marketplace.
    public var isOfficial: Bool

    public init(name: String, source: String, isOfficial: Bool = false) {
        self.name = name
        self.source = source
        self.isOfficial = isOfficial
    }
}

// MARK: - KnownMarketplacesFile

/// The `known_marketplaces.json` file content.
public struct KnownMarketplacesFile: Codable, Sendable {
    public var marketplaces: [Marketplace]

    public init(marketplaces: [Marketplace] = []) {
        self.marketplaces = marketplaces
    }
}

// MARK: - MarketplaceManager

/// Manages marketplace add/list/remove operations.
/// Git clone / pull is delegated to ProcessRunner — real registry browsing is out of scope.
public actor MarketplaceManager {
    private let cacheDir: URL
    private let knownMarketplacesFile: URL
    private let processRunner: ProcessRunnerProtocol

    public init(
        cacheDir: URL = PluginPaths.marketplacesDirectory(),
        knownMarketplacesFile: URL = PluginPaths.knownMarketplacesFile(),
        processRunner: ProcessRunnerProtocol
    ) {
        self.cacheDir = cacheDir
        self.knownMarketplacesFile = knownMarketplacesFile
        self.processRunner = processRunner
    }

    // MARK: - List

    public func list() throws -> [Marketplace] {
        guard FileManager.default.fileExists(atPath: knownMarketplacesFile.path) else {
            return []
        }
        let data = try Data(contentsOf: knownMarketplacesFile)
        let file = try JSONDecoder().decode(KnownMarketplacesFile.self, from: data)
        return file.marketplaces
    }

    // MARK: - Add

    public func add(name: String, source: String) throws {
        var marketplaces = (try? list()) ?? []
        if marketplaces.contains(where: { $0.name == name }) {
            throw MarketplaceError.alreadyExists(name)
        }
        marketplaces.append(Marketplace(name: name, source: source))
        try save(marketplaces)
    }

    // MARK: - Remove

    public func remove(name: String) throws {
        var marketplaces = (try? list()) ?? []
        let before = marketplaces.count
        marketplaces.removeAll { $0.name == name }
        if marketplaces.count == before {
            throw MarketplaceError.notFound(name)
        }
        try save(marketplaces)
    }

    // MARK: - Update (git pull)

    /// Updates a git-based marketplace. Keeps cache on failure when env var is set.
    public func update(name: String) async throws {
        let marketplaces = (try? list()) ?? []
        guard let marketplace = marketplaces.first(where: { $0.name == name }) else {
            throw MarketplaceError.notFound(name)
        }

        let marketplaceDir = cacheDir.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: marketplaceDir.path) else {
            // Not yet cloned — clone it
            try await cloneMarketplace(marketplace, to: marketplaceDir)
            return
        }

        // Attempt git pull
        do {
            _ = try await processRunner.run(
                executable: "git",
                arguments: ["pull", "--ff-only"],
                workingDirectory: marketplaceDir
            )
        } catch {
            if MarketplaceCache.keepOnFailure() {
                // Keep existing cache — do not rethrow
                return
            }
            throw error
        }
    }

    // MARK: - Private

    private func cloneMarketplace(_ marketplace: Marketplace, to dir: URL) async throws {
        try PluginPaths.ensureDirectory(dir.deletingLastPathComponent())
        _ = try await processRunner.run(
            executable: "git",
            arguments: ["clone", "--depth", "1", marketplace.source, dir.path],
            workingDirectory: nil
        )
    }

    private func save(_ marketplaces: [Marketplace]) throws {
        let file = KnownMarketplacesFile(marketplaces: marketplaces)
        let data = try JSONEncoder().encode(file)
        try PluginPaths.ensureDirectory(knownMarketplacesFile.deletingLastPathComponent())
        try data.write(to: knownMarketplacesFile, options: .atomic)
    }
}

// MARK: - MarketplaceError

public enum MarketplaceError: Error, LocalizedError {
    case alreadyExists(String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyExists(let n): return "Marketplace '\(n)' already exists"
        case .notFound(let n):      return "Marketplace '\(n)' not found"
        }
    }
}

// MARK: - ProcessRunnerProtocol (minimal interface for testability)

public protocol ProcessRunnerProtocol: Sendable {
    func run(
        executable: String,
        arguments: [String],
        workingDirectory: URL?
    ) async throws -> ProcessResultProtocol
}

public protocol ProcessResultProtocol: Sendable {
    var exitCode: Int32 { get }
    var stdout: String { get }
    var stderr: String { get }
}
