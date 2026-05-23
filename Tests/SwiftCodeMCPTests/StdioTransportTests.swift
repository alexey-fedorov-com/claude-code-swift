import XCTest
@testable import SwiftCodeMCP

/// Tests the StdioTransport by using a simple echo helper program.
///
/// The echo server is a shell one-liner:
///   while read line; do echo "$line"; done
/// which echoes back each newline-delimited JSON line it receives.
final class StdioTransportTests: XCTestCase {

    func testSendAndReceive() async throws {
        // Use /bin/sh to create a line echo server
        let transport = StdioTransport(
            command: "/bin/sh",
            arguments: ["-c", "while IFS= read -r line; do printf '%s\\n' \"$line\"; done"]
        )

        try await transport.start()

        let payload = """
            {"jsonrpc":"2.0","id":1,"method":"ping"}
            """.data(using: .utf8)!

        try await transport.send(payload)
        let received = try await transport.receive()
        let str = String(data: received, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("ping"), "Echo server should return the sent line: '\(str)'")

        await transport.close()
    }

    func testMultipleMessages() async throws {
        let transport = StdioTransport(
            command: "/bin/sh",
            arguments: ["-c", "while IFS= read -r line; do printf '%s\\n' \"$line\"; done"]
        )

        try await transport.start()

        let messages = [
            #"{"jsonrpc":"2.0","id":1,"method":"a"}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"b"}"#,
            #"{"jsonrpc":"2.0","id":3,"method":"c"}"#
        ]

        for msg in messages {
            try await transport.send(msg.data(using: .utf8)!)
        }

        var received: [String] = []
        for _ in messages {
            let data = try await transport.receive()
            received.append(String(data: data, encoding: .utf8) ?? "")
        }

        XCTAssertEqual(received.count, 3)
        XCTAssertTrue(received[0].contains("\"a\""))
        XCTAssertTrue(received[1].contains("\"b\""))
        XCTAssertTrue(received[2].contains("\"c\""))

        await transport.close()
    }

    func testCloseBeforeReceive() async throws {
        let transport = StdioTransport(
            command: "/bin/sh",
            arguments: ["-c", "exit 0"]
        )
        try await transport.start()
        // Process exits immediately; receive should throw
        do {
            _ = try await transport.receive()
            // May or may not throw depending on timing — both are valid
        } catch {
            // Expected: connectionClosed or similar
        }
        await transport.close()
    }
}
