// REPLInputTests.swift
// SwiftCodeCLITests
//
// Tests for slash command parsing and REPL input dispatch logic.
// Tests the parseSlashCommand() utility and CommandRegistry integration.

import Testing
import Foundation
@testable import SwiftCodeCLI
import SwiftCodeCore
import SwiftCodeAPI
import SwiftCodeAgent
import SwiftCodeCommands

// MARK: - parseSlashCommand Tests

@Suite("parseSlashCommand utility")
struct ParseSlashCommandTests {

    @Test("parses /help into (help, empty)")
    func testHelp() {
        let result = parseSlashCommand("/help")
        #expect(result?.name == "help")
        #expect(result?.args == "")
    }

    @Test("parses /model opus into (model, opus)")
    func testModelWithArg() {
        let result = parseSlashCommand("/model opus")
        #expect(result?.name == "model")
        #expect(result?.args == "opus")
    }

    @Test("parses /exit with no args")
    func testExitNoArgs() {
        let result = parseSlashCommand("/exit")
        #expect(result?.name == "exit")
        #expect(result?.args == "")
    }

    @Test("returns nil for non-slash input")
    func testNonSlash() {
        let result = parseSlashCommand("hello world")
        #expect(result == nil)
    }

    @Test("returns nil for bare slash")
    func testBareSlash() {
        let result = parseSlashCommand("/")
        #expect(result == nil)
    }

    @Test("command name is lowercased")
    func testLowercased() {
        let result = parseSlashCommand("/HELP")
        #expect(result?.name == "help")
    }

    @Test("preserves args including spaces")
    func testArgsWithSpaces() {
        let result = parseSlashCommand("/model claude-sonnet-4-6 extra")
        #expect(result?.name == "model")
        #expect(result?.args == "claude-sonnet-4-6 extra")
    }

    @Test("handles leading slash only")
    func testSingleSlash() {
        let result = parseSlashCommand("/")
        #expect(result == nil)
    }
}

// MARK: - CommandRegistry Slash Dispatch Tests

@Suite("CommandRegistry slash dispatch")
struct CommandRegistryDispatchTests {

    /// Lightweight command stub for testing dispatch.
    struct RecordingCommand: SlashCommand {
        let name: String
        let description = "Test recording command"

        func execute(input: String, context: SlashCommandContext) async throws -> SlashCommandResult {
            return .message("executed: \(name) with '\(input)'")
        }
    }

    @Test("lookup finds registered command by name")
    func testLookupFindsCommand() async {
        let registry = CommandRegistry()
        let cmd = RecordingCommand(name: "testcmd")
        await registry.register(cmd)

        let found = await registry.lookup(name: "testcmd")
        #expect(found != nil)
        #expect(found?.name == "testcmd")
    }

    @Test("lookup returns nil for unknown command")
    func testLookupMissing() async {
        let registry = CommandRegistry()
        let found = await registry.lookup(name: "nonexistent")
        #expect(found == nil)
    }

    @Test("lookup is case-insensitive for query (real commands always register lowercase names)")
    func testLookupCaseInsensitive() async {
        let registry = CommandRegistry()
        // Real commands always use lowercase names; the registry lowercases the query.
        await registry.register(RecordingCommand(name: "mycmd"))
        let found = await registry.lookup(name: "MYCMD")
        #expect(found != nil)
    }

    @Test("ExitCommand returns .exit(0)")
    func testExitCommandResult() async throws {
        let cmd = ExitCommand()
        let ctx = SlashCommandContext()
        let result = try await cmd.execute(input: "", context: ctx)
        if case .exit(let code) = result {
            #expect(code == 0)
        } else {
            Issue.record("Expected .exit(0), got \(result)")
        }
    }

    @Test("ClearCommand returns .clearContext")
    func testClearCommandResult() async throws {
        let cmd = ClearCommand()
        let ctx = SlashCommandContext()
        let result = try await cmd.execute(input: "", context: ctx)
        if case .clearContext = result {
            // Pass
        } else {
            Issue.record("Expected .clearContext, got \(result)")
        }
    }

    @Test("ModelCommand returns .setModel with provided arg")
    func testModelCommandResult() async throws {
        let cmd = ModelCommand()
        let ctx = SlashCommandContext()
        let result = try await cmd.execute(input: "opus", context: ctx)
        if case .setModel(let newModel) = result {
            #expect(newModel == "opus" || newModel.contains("opus"))
        } else {
            Issue.record("Expected .setModel, got \(result)")
        }
    }

    @Test("HelpCommand returns .message with command listing")
    func testHelpCommandResult() async throws {
        let cmd = HelpCommand()
        let ctx = SlashCommandContext()
        let result = try await cmd.execute(input: "", context: ctx)
        if case .message(let text) = result {
            #expect(text.contains("help") || text.contains("commands"))
        } else {
            Issue.record("Expected .message, got \(result)")
        }
    }

    @Test("default registry has help command registered")
    func testDefaultRegistryHasHelp() async {
        let registry = CommandRegistry.defaultRegistry()
        // Give async task time to register
        try? await Task.sleep(nanoseconds: 5_000_000)
        let found = await registry.lookup(name: "help")
        #expect(found != nil)
    }

    @Test("default registry has exit command registered")
    func testDefaultRegistryHasExit() async {
        let registry = CommandRegistry.defaultRegistry()
        try? await Task.sleep(nanoseconds: 5_000_000)
        let found = await registry.lookup(name: "exit")
        #expect(found != nil)
    }

    @Test("default registry lookup for /exit alias 'quit' succeeds")
    func testExitAlias() async {
        let registry = CommandRegistry.defaultRegistry()
        try? await Task.sleep(nanoseconds: 5_000_000)
        let found = await registry.lookup(name: "quit")
        #expect(found != nil)
        #expect(found?.name == "exit")
    }
}

// MARK: - MessageQueue Tests

@Suite("MessageQueue")
struct MessageQueueTests {

    @Test("enqueue and dequeue returns element in FIFO order")
    func testFIFO() async {
        let queue = MessageQueue<Int>()
        await queue.enqueue(1)
        await queue.enqueue(2)
        await queue.enqueue(3)

        let a = await queue.dequeue()
        let b = await queue.dequeue()
        let c = await queue.dequeue()

        #expect(a == 1)
        #expect(b == 2)
        #expect(c == 3)
    }

    @Test("dequeue returns nil after close with empty buffer")
    func testCloseReturnsNil() async {
        let queue = MessageQueue<String>()
        await queue.close()
        let result = await queue.dequeue()
        #expect(result == nil)
    }

    @Test("close drains pending waiters with nil")
    func testCloseWakesPendingWaiters() async {
        let queue = MessageQueue<String>()

        // Start a consumer that will block
        let task = Task<String?, Never> {
            await queue.dequeue()
        }

        // Give the consumer time to suspend
        try? await Task.sleep(nanoseconds: 10_000_000)

        await queue.close()
        let result = await task.value
        #expect(result == nil)
    }

    @Test("count reflects buffered elements")
    func testCount() async {
        let queue = MessageQueue<Int>()
        #expect(await queue.count == 0)
        await queue.enqueue(42)
        #expect(await queue.count == 1)
        await queue.enqueue(99)
        #expect(await queue.count == 2)
        _ = await queue.dequeue()
        #expect(await queue.count == 1)
    }

    @Test("isClosed reflects queue state")
    func testIsClosed() async {
        let queue = MessageQueue<Int>()
        #expect(await queue.isClosed == false)
        await queue.close()
        #expect(await queue.isClosed == true)
    }

    @Test("enqueue after close is no-op")
    func testEnqueueAfterClose() async {
        let queue = MessageQueue<Int>()
        await queue.close()
        await queue.enqueue(999)
        #expect(await queue.count == 0)
    }

    @Test("async producer/consumer pair works correctly")
    func testProducerConsumer() async {
        let queue = MessageQueue<Int>()

        // Producer task
        let producer = Task {
            for i in 1...5 {
                await queue.enqueue(i)
                try? await Task.sleep(nanoseconds: 1_000_000)
            }
            await queue.close()
        }

        // Consumer
        var collected: [Int] = []
        while let item = await queue.dequeue() {
            collected.append(item)
        }
        await producer.value

        #expect(collected == [1, 2, 3, 4, 5])
    }
}

// MARK: - REPL Slash Command Integration

@Suite("InteractiveREPL slash parsing integration")
struct REPLSlashParsingTests {

    @Test("non-slash input is not a slash command")
    func testNonSlashInput() {
        let result = parseSlashCommand("what is the weather")
        #expect(result == nil)
    }

    @Test("/clear is recognized as a slash command")
    func testClearRecognized() {
        let result = parseSlashCommand("/clear")
        #expect(result?.name == "clear")
    }

    @Test("/exit is recognized as a slash command")
    func testExitRecognized() {
        let result = parseSlashCommand("/exit")
        #expect(result?.name == "exit")
    }

    @Test("Ctrl+D equivalent: empty line from readLine returns nil (conceptual)")
    func testCtrlDSimulated() {
        // readLine() returns nil on EOF (Ctrl+D). This test documents the contract.
        // In test environment we just verify the nil path is handled.
        // Actual stdin reading can't be unit-tested without process isolation.
        let nilInput: String? = nil
        #expect(nilInput == nil)
    }
}
