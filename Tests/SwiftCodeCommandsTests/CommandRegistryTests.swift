import XCTest
@testable import SwiftCodeCommands
import SwiftCodeCore

final class CommandRegistryTests: XCTestCase {

    // MARK: - Helpers

    func makeRegistry() async -> CommandRegistry {
        let r = CommandRegistry.defaultRegistry()
        // Give the Task-based registration a moment to complete
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        return r
    }

    // MARK: - Basic registration

    func testDefaultRegistryIsNotEmpty() async throws {
        let registry = await makeRegistry()
        let commands = await registry.availableCommands(antUser: false, demoMode: false)
        XCTAssertFalse(commands.isEmpty, "Default registry should have commands")
    }

    func testRegisterAndLookup() async throws {
        let registry = CommandRegistry()
        struct Ping: SlashCommand {
            let name = "ping"
            let description = "Test command"
            func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult { .message("pong") }
        }
        await registry.register(Ping())
        let found = await registry.lookup(name: "ping")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "ping")
    }

    func testLookupReturnsNilForUnknown() async throws {
        let registry = CommandRegistry()
        let found = await registry.lookup(name: "nonexistent-command-xyz")
        XCTAssertNil(found)
    }

    func testLookupByAlias() async throws {
        let registry = CommandRegistry()
        await registry.register(ExitCommand())
        let found = await registry.lookup(name: "quit")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "exit")
    }

    // MARK: - Availability filtering

    func testAntOnlyCommandsHiddenForExternalUser() async throws {
        let registry = CommandRegistry()
        await registry.register(AntTraceCommand()) // requiresAntUser = true
        let external = await registry.availableCommands(antUser: false, demoMode: false)
        XCTAssertFalse(external.contains { $0.name == "ant-trace" })
    }

    func testAntOnlyCommandsVisibleForAntUser() async throws {
        let registry = CommandRegistry()
        await registry.register(AntTraceCommand())
        let ant = await registry.availableCommands(antUser: true, demoMode: false)
        XCTAssertTrue(ant.contains { $0.name == "ant-trace" })
    }

    func testAntOnlyCommandsHiddenInDemoMode() async throws {
        let registry = CommandRegistry()
        await registry.register(AntTraceCommand())
        let demo = await registry.availableCommands(antUser: true, demoMode: true)
        XCTAssertFalse(demo.contains { $0.name == "ant-trace" })
    }

    func testFeatureGatedCommandHiddenWhenFlagOff() async throws {
        let registry = CommandRegistry()
        await registry.register(UltraplanCommand()) // requiredFeatureFlag = .ultraplan (false)
        let commands = await registry.availableCommands(antUser: false, demoMode: false)
        XCTAssertFalse(commands.contains { $0.name == "ultraplan" })
    }

    // MARK: - allCommandNames

    func testAllCommandNamesIsNotEmpty() {
        XCTAssertFalse(CommandRegistry.allCommandNames.isEmpty)
        XCTAssertTrue(CommandRegistry.allCommandNames.count >= 80)
    }
}
