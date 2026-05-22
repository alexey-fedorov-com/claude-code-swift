import XCTest
import SwiftCodeCore
@testable import SwiftCodeTools

final class ToolRegistryTests: XCTestCase {

    func testDefaultPresetContainsCoreTools() {
        let names = ToolRegistry.shared.defaultPresetNames()
        XCTAssertTrue(names.contains("Bash"), "Default preset should contain Bash")
        XCTAssertTrue(names.contains("Read"), "Default preset should contain Read")
        XCTAssertTrue(names.contains("Edit"), "Default preset should contain Edit")
        XCTAssertTrue(names.contains("Write"), "Default preset should contain Write")
        XCTAssertTrue(names.contains("Glob"), "Default preset should contain Glob")
        XCTAssertTrue(names.contains("Grep"), "Default preset should contain Grep")
        XCTAssertTrue(names.contains("TodoWrite"), "Default preset should contain TodoWrite")
    }

    func testDefaultPresetContainsMcpTools() {
        let names = ToolRegistry.shared.defaultPresetNames()
        XCTAssertTrue(names.contains("ListMcpResources"), "MCP resource tools always in default preset")
        XCTAssertTrue(names.contains("ReadMcpResource"), "MCP resource tools always in default preset")
    }

    func testHandlerLookupFullyImplemented() {
        let tools = ["Bash", "Read", "Edit", "Write", "Glob", "Grep", "TodoWrite"]
        for name in tools {
            XCTAssertNotNil(ToolRegistry.shared.handler(for: name), "\(name) handler should be registered")
        }
    }

    func testHandlerLookupStubs() {
        // Note: tool names match each struct's `name` property (not the type name)
        let stubs = ["Agent", "AskUserQuestion", "Brief", "Config",
                     "EnterPlanMode", "ExitPlanMode", "LSP",
                     "WebFetch", "WebSearch", "Workflow"]
        for name in stubs {
            XCTAssertNotNil(ToolRegistry.shared.handler(for: name),
                            "\(name) should be registered")
        }
    }

    func testAllNamesNonEmpty() {
        XCTAssertGreaterThan(ToolRegistry.shared.allNames.count, 40,
                             "Registry should have 40+ tool names")
    }

    func testHandlersForNames() {
        let subset = ["Bash", "Read", "Edit"]
        let handlers = ToolRegistry.shared.handlers(for: subset)
        XCTAssertEqual(handlers.count, subset.count)
    }

    func testUnknownNameReturnsNil() {
        XCTAssertNil(ToolRegistry.shared.handler(for: "NonExistentTool"))
    }
}
