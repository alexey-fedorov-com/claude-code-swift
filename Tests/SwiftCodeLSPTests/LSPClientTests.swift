import XCTest
@testable import SwiftCodeLSP

/// Tests LSPClient using a tiny echo LSP server written in Python.
///
/// The server reads Content-Length frames and echoes back a fake
/// InitializeResult, then handles shutdown gracefully.
final class LSPClientTests: XCTestCase {

    // MARK: - LSP Framing roundtrip (pure unit test, no subprocess)

    func testFramingRoundtrip() {
        let json = #"{"jsonrpc":"2.0","id":1,"result":{"capabilities":{}}}"#
        let body = json.data(using: .utf8)!
        let framed = LSPFraming.frame(body)
        var buf = framed
        let parsed = LSPFraming.parse(buffer: &buf)
        XCTAssertEqual(parsed, body)
    }

    func testFrameContainsContentLength() {
        let body = "hello".data(using: .utf8)!
        let framed = LSPFraming.frame(body)
        let str = String(data: framed, encoding: .utf8)!
        XCTAssertTrue(str.hasPrefix("Content-Length: 5\r\n\r\nhello"))
    }

    // MARK: - LSPClient with echo server

    func testInitializeWithEchoServer() async throws {
        // Python one-liner LSP echo server
        // Reads Content-Length frames and returns a canned InitializeResult
        let script = """
import sys, json

def read_message():
    header = b""
    while True:
        line = sys.stdin.buffer.readline()
        if line == b"\\r\\n":
            break
        header += line
    length = 0
    for part in header.split(b"\\r\\n"):
        if part.lower().startswith(b"content-length:"):
            length = int(part.split(b":")[1].strip())
    return json.loads(sys.stdin.buffer.read(length))

def send_message(obj):
    body = json.dumps(obj).encode()
    sys.stdout.buffer.write(f"Content-Length: {len(body)}\\r\\n\\r\\n".encode())
    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()

while True:
    try:
        msg = read_message()
        method = msg.get("method", "")
        mid = msg.get("id")
        if method == "initialize":
            send_message({"jsonrpc":"2.0","id":mid,"result":{"capabilities":{"textDocumentSync":1},"serverInfo":{"name":"EchoLSP","version":"0.1"}}})
        elif method == "shutdown":
            send_message({"jsonrpc":"2.0","id":mid,"result":None})
        elif method == "exit":
            break
    except Exception:
        break
"""

        // Check if python3 is available
        let pythonCheck = Process()
        pythonCheck.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        pythonCheck.arguments = ["python3", "--version"]
        pythonCheck.standardOutput = Pipe()
        pythonCheck.standardError = Pipe()
        do {
            try pythonCheck.run()
            pythonCheck.waitUntilExit()
        } catch {
            // python3 not available, skip test
            throw XCTSkip("python3 not available")
        }
        guard pythonCheck.terminationStatus == 0 else {
            throw XCTSkip("python3 not available")
        }

        let client = LSPClient(
            serverCommand: "python3",
            serverArgs: ["-c", script]
        )

        let result = try await client.initialize(rootURI: "file:///tmp/test")
        XCTAssertNotNil(result.serverInfo)
        XCTAssertEqual(result.serverInfo?.name, "EchoLSP")
        XCTAssertEqual(result.capabilities.textDocumentSync, .full)

        try await client.shutdown()
    }

    // MARK: - DiagnosticsRegistry integration

    func testRegistryEmptyByDefault() async {
        let registry = DiagnosticsRegistry()
        let diags = await registry.diagnostics(for: "file:///anything.swift")
        XCTAssertTrue(diags.isEmpty)
    }

    func testRegistryClearAll() async {
        let registry = DiagnosticsRegistry()
        await registry.update(uri: "file:///a.swift", diagnostics: [
            Diagnostic(
                range: LSPRange(start: LSPPosition(line: 0, character: 0), end: LSPPosition(line: 0, character: 1)),
                message: "e1"
            )
        ])
        await registry.update(uri: "file:///b.swift", diagnostics: [
            Diagnostic(
                range: LSPRange(start: LSPPosition(line: 1, character: 0), end: LSPPosition(line: 1, character: 1)),
                message: "e2"
            )
        ])
        await registry.clearAll()
        let affected = await registry.affectedURIs
        XCTAssertTrue(affected.isEmpty)
    }

    func testRegistryErrorCount() async {
        let registry = DiagnosticsRegistry()
        await registry.update(uri: "file:///x.swift", diagnostics: [
            Diagnostic(range: LSPRange(start: LSPPosition(line: 0, character: 0), end: LSPPosition(line: 0, character: 1)), severity: .error, message: "err"),
            Diagnostic(range: LSPRange(start: LSPPosition(line: 1, character: 0), end: LSPPosition(line: 1, character: 1)), severity: .warning, message: "warn"),
            Diagnostic(range: LSPRange(start: LSPPosition(line: 2, character: 0), end: LSPPosition(line: 2, character: 1)), severity: .error, message: "err2")
        ])
        let errorCount = await registry.count(severity: .error)
        let warnCount = await registry.count(severity: .warning)
        XCTAssertEqual(errorCount, 2)
        XCTAssertEqual(warnCount, 1)
    }
}
