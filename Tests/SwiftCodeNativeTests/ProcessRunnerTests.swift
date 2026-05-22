import Testing
import Foundation
@testable import SwiftCodeNative

@Suite("ProcessRunner")
struct ProcessRunnerTests {

    let runner = ProcessRunner()

    // MARK: Basic execution

    @Test("testRunSimpleCommand: echo returns exit 0 and correct stdout")
    func testRunSimpleCommand() async throws {
        let result = try await runner.run(
            executable: "/bin/echo",
            arguments: ["hello"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
        #expect(result.stderr.isEmpty)
    }

    @Test("testRunFailedCommand: false returns nonzero exit")
    func testRunFailedCommand() async throws {
        let result = try await runner.run(
            executable: "/usr/bin/false",
            arguments: []
        )
        #expect(result.exitCode != 0)
    }

    @Test("testRunWithStdin: cat echoes stdin")
    func testRunWithStdin() async throws {
        let result = try await runner.run(
            executable: "/bin/cat",
            arguments: [],
            stdin: "hello from stdin"
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout == "hello from stdin")
    }

    @Test("testRunInDirectory: workingDirectory is respected")
    func testRunInDirectory() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        let result = try await runner.run(
            executable: "/bin/pwd",
            arguments: [],
            workingDirectory: tmp
        )
        #expect(result.exitCode == 0)
        // /tmp on macOS resolves to /private/tmp
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(output.hasSuffix(tmp.lastPathComponent) || output.contains("tmp"))
    }

    @Test("testRunWithEnv: environment variable passed through")
    func testRunWithEnv() async throws {
        let result = try await runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo $MY_TEST_VAR"],
            environment: ["MY_TEST_VAR": "swiftcode_test", "PATH": "/bin:/usr/bin"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "swiftcode_test")
    }

    // MARK: Streaming

    @Test("testRunStreaming: stdout callback fires with chunks")
    func testRunStreaming() async throws {
        // Use a class-based collector so the @Sendable closure can mutate it safely.
        final class Collector: @unchecked Sendable {
            var chunks: [String] = []
            let lock = NSLock()
            func add(_ s: String) { lock.withLock { chunks.append(s) } }
            var combined: String { lock.withLock { chunks.joined() } }
        }
        let collector = Collector()
        let exitCode = try await runner.runStreaming(
            executable: "/bin/echo",
            arguments: ["streaming test"],
            onStdout: { chunk in collector.add(chunk) },
            onStderr: { _ in }
        )
        #expect(exitCode == 0)
        #expect(collector.combined.trimmingCharacters(in: .whitespacesAndNewlines) == "streaming test")
    }

    // MARK: Abort

    @Test("testRunAbort: aborting mid-run kills the process")
    func testRunAbort() async throws {
        let (task, handle) = runner.runWithHandle(
            executable: "/bin/sleep",
            arguments: ["60"]
        )
        // Give the process time to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        handle.abort()
        // The task should complete quickly (process was killed)
        let result = try await task.value
        // sleep killed by SIGTERM → nonzero exit
        #expect(result.exitCode != 0)
    }

    // MARK: Timeout

    @Test("testRunWithTimeout: long-running command is killed after timeout")
    func testRunWithTimeout() async throws {
        let result = try await runner.run(
            executable: "/bin/sleep",
            arguments: ["60"],
            timeout: 0.3  // 300ms
        )
        // Terminated process → nonzero exit
        #expect(result.exitCode != 0)
    }

    // MARK: Multi-line output

    @Test("testRunMultilineOutput: all lines captured")
    func testRunMultilineOutput() async throws {
        let result = try await runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "printf 'line1\\nline2\\nline3\\n'"]
        )
        #expect(result.exitCode == 0)
        let lines = result.stdout.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 3)
        #expect(lines[0] == "line1")
        #expect(lines[2] == "line3")
    }
}
