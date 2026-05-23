/// MarketplaceCacheTests — tests for the 2.1.90 CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE backport.

import Testing
import Foundation
@testable import SwiftCodePlugins

@Suite("MarketplaceCache")
struct MarketplaceCacheTests {

    @Test("2.1.90: keepOnFailure returns false when env var not set")
    func falseWhenNotSet() {
        let result = MarketplaceCache.keepOnFailure(env: [:])
        #expect(!result)
    }

    @Test("2.1.90: keepOnFailure returns true when env var is 'true'")
    func trueWhenTrue() {
        let result = MarketplaceCache.keepOnFailure(env: [
            "CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE": "true"
        ])
        #expect(result)
    }

    @Test("2.1.90: keepOnFailure returns true when env var is '1'")
    func trueWhenOne() {
        let result = MarketplaceCache.keepOnFailure(env: [
            "CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE": "1"
        ])
        #expect(result)
    }

    @Test("2.1.90: keepOnFailure returns true when env var is 'yes'")
    func trueWhenYes() {
        let result = MarketplaceCache.keepOnFailure(env: [
            "CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE": "yes"
        ])
        #expect(result)
    }

    @Test("2.1.90: keepOnFailure returns false when env var is 'false'")
    func falseWhenFalse() {
        let result = MarketplaceCache.keepOnFailure(env: [
            "CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE": "false"
        ])
        #expect(!result)
    }

    @Test("2.1.90: keepOnFailure returns false when env var is '0'")
    func falseWhenZero() {
        let result = MarketplaceCache.keepOnFailure(env: [
            "CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE": "0"
        ])
        #expect(!result)
    }

    @Test("env var name is correct")
    func envVarName() {
        #expect(MarketplaceCache.envVarName == "CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE")
    }

    @Test("Marketplace is Codable and roundtrips")
    func marketplaceCodeable() throws {
        let marketplace = Marketplace(name: "my-market", source: "https://example.com", isOfficial: false)
        let data = try JSONEncoder().encode(marketplace)
        let decoded = try JSONDecoder().decode(Marketplace.self, from: data)
        #expect(decoded.name == "my-market")
        #expect(decoded.source == "https://example.com")
        #expect(!decoded.isOfficial)
    }

    @Test("MarketplaceManager add and list work")
    func addAndList() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("marketplace-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let knownFile = tmpDir.appendingPathComponent("known_marketplaces.json")
        let runner = MockProcessRunnerForMarket()
        let manager = MarketplaceManager(
            cacheDir: tmpDir.appendingPathComponent("cache"),
            knownMarketplacesFile: knownFile,
            processRunner: runner
        )

        try await manager.add(name: "test-market", source: "https://example.com/market")
        let list = try await manager.list()
        #expect(list.count == 1)
        #expect(list[0].name == "test-market")
        #expect(list[0].source == "https://example.com/market")
    }

    @Test("MarketplaceManager remove works")
    func removeMarketplace() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("marketplace-remove-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let knownFile = tmpDir.appendingPathComponent("known_marketplaces.json")
        let runner = MockProcessRunnerForMarket()
        let manager = MarketplaceManager(
            cacheDir: tmpDir.appendingPathComponent("cache"),
            knownMarketplacesFile: knownFile,
            processRunner: runner
        )

        try await manager.add(name: "to-remove", source: "https://example.com")
        var list = try await manager.list()
        #expect(list.count == 1)

        try await manager.remove(name: "to-remove")
        list = try await manager.list()
        #expect(list.isEmpty)
    }

    @Test("MarketplaceManager throws notFound when removing non-existent market")
    func throwsNotFoundOnRemove() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("marketplace-nf-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let knownFile = tmpDir.appendingPathComponent("known_marketplaces.json")
        let runner = MockProcessRunnerForMarket()
        let manager = MarketplaceManager(
            cacheDir: tmpDir,
            knownMarketplacesFile: knownFile,
            processRunner: runner
        )

        var didThrow = false
        do {
            try await manager.remove(name: "ghost")
        } catch MarketplaceError.notFound {
            didThrow = true
        }
        #expect(didThrow)
    }
}

// MARK: - MockProcessRunnerForMarket

final class MockProcessRunnerForMarket: ProcessRunnerProtocol, @unchecked Sendable {
    func run(
        executable: String,
        arguments: [String],
        workingDirectory: URL?
    ) async throws -> ProcessResultProtocol {
        MockMarketResult(exitCode: 0, stdout: "", stderr: "")
    }
}

struct MockMarketResult: ProcessResultProtocol {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
