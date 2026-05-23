import XCTest
@testable import SwiftCodeCore

final class TelemetryTests: XCTestCase {

    // MARK: - Opt-out gating

    func testEnabled_byDefault() async {
        let t = Telemetry(sinks: [], env: [:])
        let enabled = await t.isEnabled()
        XCTAssertTrue(enabled)
    }

    func testDisabled_viaCLAUDE_CODE_TELEMETRY_zero() async {
        let t = Telemetry(sinks: [], env: ["CLAUDE_CODE_TELEMETRY": "0"])
        let enabled = await t.isEnabled()
        XCTAssertFalse(enabled)
    }

    func testDisabled_viaCLAUDE_CODE_TELEMETRY_false() async {
        let t = Telemetry(sinks: [], env: ["CLAUDE_CODE_TELEMETRY": "false"])
        let enabled = await t.isEnabled()
        XCTAssertFalse(enabled)
    }

    func testDisabled_viaDISABLE_TELEMETRY_one() async {
        let t = Telemetry(sinks: [], env: ["DISABLE_TELEMETRY": "1"])
        let enabled = await t.isEnabled()
        XCTAssertFalse(enabled)
    }

    func testDisabled_viaDISABLE_TELEMETRY_true() async {
        let t = Telemetry(sinks: [], env: ["DISABLE_TELEMETRY": "true"])
        let enabled = await t.isEnabled()
        XCTAssertFalse(enabled)
    }

    func testDisabled_viaOTEL_SDK_DISABLED() async {
        let t = Telemetry(sinks: [], env: ["OTEL_SDK_DISABLED": "true"])
        let enabled = await t.isEnabled()
        XCTAssertFalse(enabled)
    }

    func testEnabled_whenOTEL_SDK_DISABLED_isFalse() async {
        let t = Telemetry(sinks: [], env: ["OTEL_SDK_DISABLED": "false"])
        let enabled = await t.isEnabled()
        XCTAssertTrue(enabled)
    }

    // MARK: - Privacy level

    func testPrivacyLevel_default_isFull() async {
        let t = Telemetry(sinks: [], env: [:])
        let level = await t.privacyLevel()
        XCTAssertEqual(level, .full)
    }

    func testPrivacyLevel_envVar_minimal() async {
        let t = Telemetry(sinks: [], env: ["CLAUDE_CODE_TELEMETRY_LEVEL": "minimal"])
        let level = await t.privacyLevel()
        XCTAssertEqual(level, .minimal)
    }

    func testPrivacyLevel_envVar_off() async {
        let t = Telemetry(sinks: [], env: ["CLAUDE_CODE_TELEMETRY_LEVEL": "off"])
        let level = await t.privacyLevel()
        XCTAssertEqual(level, .off)
    }

    // MARK: - Sink dispatch

    func testEmit_callsSink() async {
        let sink = RecordingSink()
        let t = Telemetry(sinks: [sink], env: [:])
        let event = TelemetryEvent.sessionStart(sessionID: "test-session")
        await t.emit(event)
        let recorded = await sink.recorded
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded[0].name, TelemetryEventName.sessionStart)
    }

    func testEmit_doesNotCallSink_whenDisabled() async {
        let sink = RecordingSink()
        let t = Telemetry(sinks: [sink], env: ["DISABLE_TELEMETRY": "1"])
        await t.emit(.sessionStart(sessionID: "s"))
        let recorded = await sink.recorded
        XCTAssertEqual(recorded.count, 0)
    }

    func testEmit_filtersEventsByPrivacyLevel() async {
        let sink = RecordingSink()
        // Set level to minimal — full-privacy events should be dropped
        let t = Telemetry(sinks: [sink], env: ["CLAUDE_CODE_TELEMETRY_LEVEL": "minimal"])
        let fullEvent = TelemetryEvent(name: "tool.call", privacyLevel: .full)
        let minimalEvent = TelemetryEvent(name: "error", privacyLevel: .minimal)
        await t.emit(fullEvent)
        await t.emit(minimalEvent)
        let recorded = await sink.recorded
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded[0].name, "error")
    }

    // MARK: - PrivacyLevel ordering

    func testPrivacyLevelOrdering() {
        XCTAssertLessThan(PrivacyLevel.off, PrivacyLevel.minimal)
        XCTAssertLessThan(PrivacyLevel.minimal, PrivacyLevel.full)
        XCTAssertFalse(PrivacyLevel.full < PrivacyLevel.minimal)
    }

    // MARK: - TelemetryEvent convenience constructors

    func testSessionStartEvent() {
        let event = TelemetryEvent.sessionStart(sessionID: "abc")
        XCTAssertEqual(event.name, TelemetryEventName.sessionStart)
        XCTAssertEqual(event.sessionID, "abc")
        XCTAssertEqual(event.privacyLevel, .minimal)
    }

    func testErrorEvent() {
        let event = TelemetryEvent.error("something broke", sessionID: "s1")
        XCTAssertEqual(event.name, TelemetryEventName.error)
        XCTAssertEqual(event.sessionID, "s1")
    }

    func testToolCallEvent() {
        let event = TelemetryEvent.toolCall(name: "BashTool", sessionID: "s2")
        XCTAssertEqual(event.name, TelemetryEventName.toolCall)
        XCTAssertEqual(event.privacyLevel, .full)
    }
}

// MARK: - Test helpers

actor RecordingSink: TelemetrySink {
    var recorded: [TelemetryEvent] = []

    func send(_ event: TelemetryEvent) async throws {
        recorded.append(event)
    }
}
