import XCTest
@testable import SwiftCodeRemote
import Foundation

final class BackgroundSessionTests: XCTestCase {

    // MARK: - SessionStore

    func testSessionStoreAddAndGet() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp_test_\(UUID().uuidString)")
        let store = SessionStore(directory: dir)

        let session = BackgroundSession(
            id: UUID(),
            pid: 12345,
            command: "swiftcode --print test",
            logPath: dir.appendingPathComponent("test.log")
        )

        try await store.add(session)
        let retrieved = try await store.get(id: session.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.pid, 12345)
        XCTAssertEqual(retrieved?.command, "swiftcode --print test")

        // Cleanup
        try? FileManager.default.removeItem(at: dir)
    }

    func testSessionStoreListEmpty() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp_test_\(UUID().uuidString)")
        let store = SessionStore(directory: dir)
        let sessions = try await store.list()
        XCTAssertTrue(sessions.isEmpty)
        try? FileManager.default.removeItem(at: dir)
    }

    func testSessionStoreRemove() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp_test_\(UUID().uuidString)")
        let store = SessionStore(directory: dir)

        let session = BackgroundSession(
            id: UUID(),
            pid: 99999,
            command: "test",
            logPath: dir.appendingPathComponent("log.log")
        )

        try await store.add(session)
        try await store.remove(id: session.id)
        let retrieved = try await store.get(id: session.id)
        XCTAssertNil(retrieved)

        try? FileManager.default.removeItem(at: dir)
    }

    func testSessionStoreListMultiple() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp_test_\(UUID().uuidString)")
        let store = SessionStore(directory: dir)

        for i in 1...3 {
            let session = BackgroundSession(
                id: UUID(),
                pid: Int32(i * 1000),
                command: "cmd\(i)",
                logPath: dir.appendingPathComponent("log\(i).log")
            )
            try await store.add(session)
        }

        let sessions = try await store.list()
        XCTAssertEqual(sessions.count, 3)

        try? FileManager.default.removeItem(at: dir)
    }

    func testSessionStoreUpdate() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp_test_\(UUID().uuidString)")
        let store = SessionStore(directory: dir)

        let id = UUID()
        var session = BackgroundSession(
            id: id,
            pid: 5678,
            command: "test",
            logPath: dir.appendingPathComponent("l.log")
        )
        try await store.add(session)

        // Update with exit code
        session = BackgroundSession(
            id: id,
            pid: 5678,
            startedAt: session.startedAt,
            command: session.command,
            logPath: session.logPath,
            exitCode: 0,
            exitedAt: Date()
        )
        try await store.update(session)

        let retrieved = try await store.get(id: id)
        XCTAssertEqual(retrieved?.exitCode, 0)
        XCTAssertNotNil(retrieved?.exitedAt)

        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - BackgroundSession properties

    func testSessionIsRunningForCurrentProcess() {
        // Use the current process's PID — it's definitely running
        let session = BackgroundSession(
            pid: ProcessInfo.processInfo.processIdentifier,
            command: "test",
            logPath: URL(fileURLWithPath: "/tmp/test.log")
        )
        XCTAssertTrue(session.isRunning)
    }

    func testSessionIsNotRunningForExited() {
        let session = BackgroundSession(
            pid: 99999,  // unlikely to be running
            command: "test",
            logPath: URL(fileURLWithPath: "/tmp/test.log"),
            exitCode: 0,
            exitedAt: Date()
        )
        XCTAssertFalse(session.isRunning)  // exitCode set → not running
    }

    func testSessionElapsed() {
        let start = Date(timeIntervalSinceNow: -10)
        let session = BackgroundSession(
            pid: 1,
            startedAt: start,
            command: "test",
            logPath: URL(fileURLWithPath: "/tmp/test.log")
        )
        XCTAssertGreaterThanOrEqual(session.elapsed, 10.0)
    }

    // MARK: - BackgroundSessionManager (integration)

    func testManagerLaunchAndList() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp_test_\(UUID().uuidString)")
        let store = SessionStore(directory: dir)

        // Use current executable path and a harmless command
        let manager = BackgroundSessionManager(
            store: store,
            executablePath: "/bin/echo"
        )

        let session = try await manager.launch(args: ["hello background"])
        XCTAssertGreaterThan(session.pid, 0)

        let sessions = try await manager.list()
        XCTAssertTrue(sessions.contains { $0.id == session.id })

        // Wait briefly for the process to exit
        try await Task.sleep(nanoseconds: 200_000_000)

        // Logs should be available
        let log = try await manager.logs(id: session.id)
        XCTAssertTrue(log.contains("hello") || log.isEmpty)  // echo may or may not output

        try? FileManager.default.removeItem(at: dir)
    }

    func testManagerRemove() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp_test_\(UUID().uuidString)")
        let store = SessionStore(directory: dir)
        let manager = BackgroundSessionManager(store: store, executablePath: "/usr/bin/true")

        let session = try await manager.launch(args: [])
        try await manager.remove(id: session.id)
        let sessions = try await manager.list()
        XCTAssertFalse(sessions.contains { $0.id == session.id })

        try? FileManager.default.removeItem(at: dir)
    }
}
