import XCTest
@testable import SwiftCodeCore

final class MessageCodableTests: XCTestCase {
    func testUserTextMessageRoundTrips() throws {
        let message = Message.user(UserMessage(uuid: "00000000-0000-0000-0000-000000000001", content: .text("hello"), isMeta: false))
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertEqual(decoded, message)
    }

    func testAssistantToolUseMessageRoundTrips() throws {
        let message = Message.assistant(AssistantMessage(
            uuid: "00000000-0000-0000-0000-000000000002",
            content: [.toolUse(id: "toolu_1", name: "Read", input: ["file_path": .string("README.md")])],
            usage: nil,
            stopReason: nil
        ))
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        XCTAssertEqual(decoded, message)
    }
}
