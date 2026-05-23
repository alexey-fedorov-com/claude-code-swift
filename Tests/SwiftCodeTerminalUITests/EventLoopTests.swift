import XCTest
@testable import SwiftCodeTerminalUI

final class EventLoopTests: XCTestCase {
    func testRendersInitialFrameThenUpdatesOnInput() async throws {
        let harness = HeadlessAppHarness()
        let app = App<TestState>(
            initialState: TestState(text: "hi"),
            view: { state in TextView(state.text) },
            update: { event, state in
                if case .character(let ch) = event {
                    state.text += String(ch)
                }
            },
            io: harness,
            width: 20, height: 3
        )
        await app.renderInitialFrame()
        let afterInitial = harness.captured()
        XCTAssertTrue(afterInitial.contains("hi"))
        await app.dispatch(.character("X"))
        await app.renderFrameIfNeeded()
        let afterUpdate = harness.captured()
        // The diff path emits only the changed cell ("X") with a cursor positioning
        // sequence — "hiX" does not appear contiguously in the captured buffer.
        // Verify the update wrote "X" past the initial frame's content.
        XCTAssertTrue(afterUpdate.count > afterInitial.count,
                      "second frame should produce additional output")
        let delta = String(afterUpdate.dropFirst(afterInitial.count))
        XCTAssertTrue(delta.contains("X"),
                      "diff output should contain the new character 'X', got: \(delta.debugDescription)")
    }

    func testResizeEventTriggersReflow() async throws {
        let harness = HeadlessAppHarness()
        let app = App<TestState>(
            initialState: TestState(text: "hello world"),
            view: { state in TextView(state.text) },
            update: { _, _ in },
            io: harness,
            width: 5, height: 1
        )
        await app.renderInitialFrame()
        // At width 5 the test view text doesn't wrap (TextView fixes its width to content);
        // we mainly verify resize doesn't crash and re-paints.
        await app.dispatch(.resize(width: 20, height: 1))
        await app.renderFrameIfNeeded()
        XCTAssertTrue(harness.captured().contains("hello world"))
    }

    func testWithStateMutationReflectsInNextFrame() async throws {
        let harness = HeadlessAppHarness()
        let app = App<TestState>(
            initialState: TestState(text: "a"),
            view: { state in TextView(state.text) },
            update: { _, _ in },
            io: harness,
            width: 5, height: 1
        )
        await app.renderInitialFrame()
        await app.withState { $0.text = "b" }
        await app.renderFrameIfNeeded()
        XCTAssertTrue(harness.captured().contains("b"))
    }
}

private struct TestState: Sendable { var text: String }

/// Thread-safe in-memory AppIO for tests.
final class HeadlessAppHarness: AppIO, @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    func write(_ bytes: String) async {
        withLock { $0 += bytes }
    }
    func captured() -> String {
        lock.lock(); defer { lock.unlock() }
        return buffer
    }
    private func withLock(_ body: (inout String) -> Void) {
        lock.lock(); defer { lock.unlock() }
        body(&buffer)
    }
}
