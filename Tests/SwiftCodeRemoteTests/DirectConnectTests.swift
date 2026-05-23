import XCTest
@testable import SwiftCodeRemote
import Foundation

final class DirectConnectTests: XCTestCase {

    // MARK: - DirectConnectConfig.parseServer

    func testParseServerURL() throws {
        let config = try DirectConnectConfig.parseServer("wss://claude.ai/sessions/abc")
        if case .server(let url) = config.mode {
            XCTAssertEqual(url.host, "claude.ai")
            XCTAssertEqual(url.path, "/sessions/abc")
        } else {
            XCTFail("Expected .server mode")
        }
    }

    func testParseInvalidURL() {
        XCTAssertThrowsError(try DirectConnectConfig.parseServer("not a url !!!")) { error in
            if let e = error as? DirectConnectError, case .invalidURL = e {
                // correct
            } else {
                XCTFail("Expected DirectConnectError.invalidURL")
            }
        }
    }

    // MARK: - DirectConnectConfig.parseSSH

    func testParseSSHWithUserAndPort() {
        let config = DirectConnectConfig.parseSSH("admin@192.168.1.100:2222")
        if case .ssh(let host, let port, let user) = config.mode {
            XCTAssertEqual(host, "192.168.1.100")
            XCTAssertEqual(port, 2222)
            XCTAssertEqual(user, "admin")
        } else {
            XCTFail("Expected .ssh mode")
        }
    }

    func testParseSSHHostOnly() {
        let config = DirectConnectConfig.parseSSH("myserver.example.com")
        if case .ssh(let host, let port, let user) = config.mode {
            XCTAssertEqual(host, "myserver.example.com")
            XCTAssertNil(port)
            XCTAssertNil(user)
        } else {
            XCTFail("Expected .ssh mode")
        }
    }

    func testParseSSHWithUser() {
        let config = DirectConnectConfig.parseSSH("alice@myserver.example.com")
        if case .ssh(let host, let port, let user) = config.mode {
            XCTAssertEqual(host, "myserver.example.com")
            XCTAssertNil(port)
            XCTAssertEqual(user, "alice")
        } else {
            XCTFail("Expected .ssh mode")
        }
    }

    func testParseSSHWithPort() {
        let config = DirectConnectConfig.parseSSH("myserver.example.com:22")
        if case .ssh(let host, let port, _) = config.mode {
            XCTAssertEqual(host, "myserver.example.com")
            XCTAssertEqual(port, 22)
        } else {
            XCTFail("Expected .ssh mode")
        }
    }

    // MARK: - DirectConnectConfig.parseOpen

    func testParseOpen() {
        let sessionId = "session-abc-123"
        let config = DirectConnectConfig.parseOpen(sessionId)
        if case .open(let id) = config.mode {
            XCTAssertEqual(id, sessionId)
        } else {
            XCTFail("Expected .open mode")
        }
    }

    // MARK: - SDKWebSocketConfig.parse

    func testSDKWebSocketParseWS() throws {
        let config = try SDKWebSocketConfig.parse("ws://localhost:8080/agent")
        XCTAssertEqual(config.url.scheme, "ws")
        XCTAssertEqual(config.url.host, "localhost")
        XCTAssertEqual(config.url.port, 8080)
    }

    func testSDKWebSocketParseWSS() throws {
        let config = try SDKWebSocketConfig.parse("wss://api.example.com/agent")
        XCTAssertEqual(config.url.scheme, "wss")
        XCTAssertEqual(config.url.host, "api.example.com")
    }

    func testSDKWebSocketInvalidScheme() {
        XCTAssertThrowsError(try SDKWebSocketConfig.parse("https://example.com")) { error in
            if let e = error as? SDKWebSocketError, case .invalidScheme = e {
                // correct
            } else {
                XCTFail("Expected SDKWebSocketError.invalidScheme")
            }
        }
    }

    func testSDKWebSocketInvalidURL() {
        XCTAssertThrowsError(try SDKWebSocketConfig.parse("not a url!!!")) { error in
            if let e = error as? SDKWebSocketError, case .invalidURL = e {
                // correct
            } else {
                XCTFail("Expected SDKWebSocketError.invalidURL")
            }
        }
    }

    func testSDKWebSocketWithBearerAndSession() throws {
        let config = try SDKWebSocketConfig.parse(
            "wss://api.example.com",
            bearerToken: "tok123",
            sessionId: "sess-456"
        )
        XCTAssertEqual(config.bearerToken, "tok123")
        XCTAssertEqual(config.sessionId, "sess-456")
    }

    // MARK: - DirectConnect (stub behavior)

    func testDirectConnectAlwaysThrows() async {
        let config = try? DirectConnectConfig.parseServer("https://example.com")
        guard let config else { return }
        let connect = DirectConnect(config: config)
        do {
            try await connect.connect()
            XCTFail("Should throw notImplemented")
        } catch DirectConnectError.notImplemented {
            // Expected
        } catch {
            // Other errors also acceptable for stub
        }
    }

    // MARK: - Bridge

    func testBridgeModeDisabled() {
        XCTAssertFalse(BRIDGE_MODE_ENABLED)
    }

    func testBridgeStartIsNoop() async {
        let bridge = Bridge()
        await bridge.start()
        // No crash = pass
    }

    // MARK: - Coordinator

    func testCoordinatorModeDisabled() {
        XCTAssertFalse(COORDINATOR_MODE_ENABLED)
    }

    func testCoordinatorLocalTaskManagement() async {
        let coord = Coordinator()
        let task = CoordinatorTask(title: "Write tests", description: "Add unit tests")
        await coord.addTask(task)

        let tasks = await coord.listTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].title, "Write tests")

        await coord.updateStatus(task.id, status: .inProgress)
        let updated = await coord.listTasks()
        XCTAssertEqual(updated[0].status, .inProgress)
    }

    // MARK: - TaskListWatcher

    func testTaskListWatcherLocalTasks() async {
        let watcher = TaskListWatcher()
        let entry = TaskListEntry(title: "Implement feature X", priority: .high)
        await watcher.add(entry)

        let all = await watcher.allTasks
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].title, "Implement feature X")
        XCTAssertEqual(all[0].priority, .high)
    }

    func testTaskListWatcherFilter() async {
        let watcher = TaskListWatcher()
        await watcher.add(TaskListEntry(title: "Task 1", status: .pending))
        await watcher.add(TaskListEntry(title: "Task 2", status: .inProgress))
        await watcher.add(TaskListEntry(title: "Task 3", status: .pending))

        let pending = await watcher.tasks(for: .pending)
        XCTAssertEqual(pending.count, 2)

        let inProgress = await watcher.tasks(for: .inProgress)
        XCTAssertEqual(inProgress.count, 1)
    }
}
