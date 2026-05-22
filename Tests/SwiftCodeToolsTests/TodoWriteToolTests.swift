import XCTest
import SwiftCodeCore
@testable import SwiftCodeTools

final class TodoWriteToolTests: XCTestCase {

    func makeTool(session: String = "test-\(UUID().uuidString)") -> TodoWriteTool {
        TodoWriteTool(sessionId: session)
    }

    override func setUp() async throws {
        // Nothing to set up
    }

    func testWritesAndReturnsCount() async throws {
        let tool = makeTool()
        let todos: JSONValue = .array([
            .object(["id": .string("1"), "content": .string("Do A"), "status": .string("pending")]),
            .object(["id": .string("2"), "content": .string("Do B"), "status": .string("in_progress")]),
            .object(["id": .string("3"), "content": .string("Done C"), "status": .string("completed")])
        ])
        let output = try await tool.execute(input: ["todos": todos])
        XCTAssertTrue(output.contains("3 items"), "Output should mention item count: \(output)")
        XCTAssertTrue(output.contains("1 in-progress"), "Should show in-progress count: \(output)")
        XCTAssertTrue(output.contains("1 pending"), "Should show pending count: \(output)")
        XCTAssertTrue(output.contains("1 completed"), "Should show completed count: \(output)")
    }

    func testTodosArePersisted() async throws {
        let sessionId = "persist-test-\(UUID().uuidString)"
        let tool = TodoWriteTool(sessionId: sessionId)
        let todos: JSONValue = .array([
            .object(["id": .string("1"), "content": .string("Task"), "status": .string("pending")])
        ])
        _ = try await tool.execute(input: ["todos": todos])
        let items = await TodoStore.shared.get(sessionId: sessionId)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].content, "Task")
        XCTAssertEqual(items[0].status, .pending)
    }

    func testReplacesExistingTodos() async throws {
        let sessionId = "replace-test-\(UUID().uuidString)"
        let tool = TodoWriteTool(sessionId: sessionId)

        // First write
        _ = try await tool.execute(input: ["todos": .array([
            .object(["id": .string("1"), "content": .string("Old"), "status": .string("pending")])
        ])])

        // Second write replaces
        _ = try await tool.execute(input: ["todos": .array([
            .object(["id": .string("2"), "content": .string("New"), "status": .string("completed")])
        ])])

        let items = await TodoStore.shared.get(sessionId: sessionId)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].content, "New")
    }

    func testMissingTodosThrows() async {
        let tool = makeTool()
        do {
            _ = try await tool.execute(input: [:])
            XCTFail("Should throw for missing todos")
        } catch ToolError.invalidInput { /* expected */ }
          catch { XCTFail("Unexpected: \(error)") }
    }

    func testInvalidStatusThrows() async {
        let tool = makeTool()
        let bad: JSONValue = .array([
            .object(["id": .string("1"), "content": .string("x"), "status": .string("invalid_status")])
        ])
        do {
            _ = try await tool.execute(input: ["todos": bad])
            XCTFail("Should throw for invalid status")
        } catch ToolError.invalidInput { /* expected */ }
          catch { XCTFail("Unexpected: \(error)") }
    }

    func testToolName() {
        XCTAssertEqual(TodoWriteTool().name, "TodoWrite")
    }
}
