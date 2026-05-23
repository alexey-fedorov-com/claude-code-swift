import XCTest
@testable import SwiftCodeLSP

final class LSPMessageTests: XCTestCase {

    // MARK: - LSPId

    func testLSPIdNumber() throws {
        let id = LSPId.number(99)
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(LSPId.self, from: data)
        XCTAssertEqual(id, decoded)
    }

    func testLSPIdString() throws {
        let id = LSPId.string("request-1")
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(LSPId.self, from: data)
        XCTAssertEqual(id, decoded)
    }

    func testLSPIdNull() throws {
        let id = LSPId.null
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(LSPId.self, from: data)
        XCTAssertEqual(id, decoded)
    }

    // MARK: - LSPRequest

    func testLSPRequestEncoding() throws {
        let req = LSPRequest(
            id: .number(1),
            method: "initialize",
            params: AnyCodable(["processId": 1234])
        )
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(LSPRequest.self, from: data)
        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.id, .number(1))
        XCTAssertEqual(decoded.method, "initialize")
    }

    // MARK: - LSPNotification

    func testLSPNotificationEncoding() throws {
        let notif = LSPNotification(method: "initialized", params: AnyCodable([:] as [String: Any]))
        let data = try JSONEncoder().encode(notif)
        let decoded = try JSONDecoder().decode(LSPNotification.self, from: data)
        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.method, "initialized")
    }

    // MARK: - LSPResponse

    func testLSPResponseWithResult() throws {
        let resp = LSPResponse(id: .number(1), result: AnyCodable("ok"))
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(LSPResponse.self, from: data)
        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertNil(decoded.error)
    }

    func testLSPResponseWithError() throws {
        let resp = LSPResponse(
            id: .number(2),
            error: LSPError(code: LSPError.methodNotFound, message: "Unknown method")
        )
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(LSPResponse.self, from: data)
        XCTAssertNotNil(decoded.error)
        XCTAssertEqual(decoded.error?.code, -32601)
    }

    // MARK: - LSPFraming

    func testFrameAndParse() {
        let body = #"{"jsonrpc":"2.0","id":1,"method":"test"}"#.data(using: .utf8)!
        let framed = LSPFraming.frame(body)

        // Should have Content-Length header
        let str = String(data: framed, encoding: .utf8)!
        XCTAssertTrue(str.hasPrefix("Content-Length: \(body.count)\r\n\r\n"))

        // Should parse back
        var buffer = framed
        let parsed = LSPFraming.parse(buffer: &buffer)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed, body)
        XCTAssertTrue(buffer.isEmpty)  // remainder should be empty
    }

    func testPartialFrameReturnsNil() {
        let body = #"{"test": "data"}"#.data(using: .utf8)!
        var buffer = LSPFraming.frame(body).dropLast(5)  // truncate
        var buf = Data(buffer)
        let result = LSPFraming.parse(buffer: &buf)
        XCTAssertNil(result)
    }

    func testMultipleFrames() {
        let body1 = #"{"id":1}"#.data(using: .utf8)!
        let body2 = #"{"id":2}"#.data(using: .utf8)!
        var buffer = LSPFraming.frame(body1) + LSPFraming.frame(body2)

        let msg1 = LSPFraming.parse(buffer: &buffer)
        XCTAssertEqual(msg1, body1)

        let msg2 = LSPFraming.parse(buffer: &buffer)
        XCTAssertEqual(msg2, body2)

        XCTAssertTrue(buffer.isEmpty)
    }

    // MARK: - Capabilities

    func testClientCapabilitiesCodable() throws {
        let caps = ClientCapabilities()
        let data = try JSONEncoder().encode(caps)
        XCTAssertFalse(data.isEmpty)
    }

    // MARK: - Diagnostics

    func testDiagnosticCodable() throws {
        let diag = Diagnostic(
            range: LSPRange(
                start: LSPPosition(line: 0, character: 5),
                end: LSPPosition(line: 0, character: 10)
            ),
            severity: .error,
            code: "E001",
            source: "swiftc",
            message: "Undeclared identifier"
        )
        let data = try JSONEncoder().encode(diag)
        let decoded = try JSONDecoder().decode(Diagnostic.self, from: data)
        XCTAssertEqual(decoded.message, "Undeclared identifier")
        XCTAssertEqual(decoded.severity, .error)
        XCTAssertEqual(decoded.range.start.line, 0)
    }

    func testDiagnosticSeverityOrder() {
        XCTAssertLessThan(DiagnosticSeverity.error, .warning)
        XCTAssertLessThan(DiagnosticSeverity.warning, .information)
        XCTAssertLessThan(DiagnosticSeverity.information, .hint)
    }

    // MARK: - DiagnosticsRegistry

    func testDiagnosticsRegistryUpdate() async {
        let registry = DiagnosticsRegistry()
        let diag = Diagnostic(
            range: LSPRange(start: LSPPosition(line: 1, character: 0), end: LSPPosition(line: 1, character: 5)),
            severity: .warning,
            message: "Unused variable"
        )
        await registry.update(uri: "file:///test.swift", diagnostics: [diag])
        let results = await registry.diagnostics(for: "file:///test.swift")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].message, "Unused variable")
    }

    func testDiagnosticsRegistryClear() async {
        let registry = DiagnosticsRegistry()
        let diag = Diagnostic(
            range: LSPRange(start: LSPPosition(line: 0, character: 0), end: LSPPosition(line: 0, character: 1)),
            message: "error"
        )
        await registry.update(uri: "file:///foo.swift", diagnostics: [diag])
        await registry.clear(uri: "file:///foo.swift")
        let results = await registry.diagnostics(for: "file:///foo.swift")
        XCTAssertTrue(results.isEmpty)
    }

    func testDiagnosticsRegistryFormatted() async {
        let registry = DiagnosticsRegistry()
        await registry.update(uri: "file:///test.swift", diagnostics: [
            Diagnostic(
                range: LSPRange(
                    start: LSPPosition(line: 4, character: 2),
                    end: LSPPosition(line: 4, character: 8)
                ),
                severity: .error,
                message: "Expected ')'"
            )
        ])
        let formatted = await registry.formatted(uri: "file:///test.swift")
        XCTAssertTrue(formatted.contains("error"))
        XCTAssertTrue(formatted.contains("5:3"))  // 1-indexed
        XCTAssertTrue(formatted.contains("Expected ')'"))
    }
}
