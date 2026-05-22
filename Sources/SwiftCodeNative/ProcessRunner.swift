/// Process execution with streaming output and abort support.
///
/// Mirrors the TypeScript reference at:
/// - src/utils/Shell.ts (exec / spawn)
/// - src/utils/ShellCommand.ts (wrapSpawn / createAbortedCommand)
///
/// Uses Foundation's `Process` API with Pipes for stdout/stderr/stdin.

import Foundation

// MARK: - Types

/// The result of a completed process.
public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// A handle that allows aborting a running process.
public final class AbortHandle: Sendable {
    private let _terminate: @Sendable () -> Void

    init(terminate: @Sendable @escaping () -> Void) {
        _terminate = terminate
    }

    /// Sends SIGTERM to the running process.
    public func abort() {
        _terminate()
    }
}

// MARK: - Internal thread-safe accumulator

/// Lock-protected data accumulator for concurrent read-ability handlers.
///
/// Using a class rather than capturing `var` directly sidesteps Swift 6's
/// `SendableClosureCaptures` restriction on mutable captures in concurrent closures.
private final class DataAccumulator: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.withLock { data.append(chunk) }
    }

    func collected() -> Data {
        lock.withLock { data }
    }
}

// MARK: - ProcessRunner

/// Actor that spawns subprocesses with stdout/stderr streaming and abort support.
///
/// All methods are safe to call from concurrent Swift async contexts.
public actor ProcessRunner {

    public init() {}

    // MARK: Simple run

    /// Runs a process and collects all output, returning when the process exits.
    ///
    /// - Parameters:
    ///   - executable: Path or name of the executable (resolved via `/usr/bin/env`
    ///     when not an absolute path).
    ///   - arguments: Command-line arguments.
    ///   - workingDirectory: Working directory for the child process.
    ///   - environment: Environment dictionary. `nil` inherits the parent environment.
    ///   - stdin: Optional string to write to the child's stdin.
    ///   - timeout: Optional wall-clock timeout in seconds. When exceeded the
    ///     process is terminated.
    public func run(
        executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        stdin stdinString: String? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> ProcessResult {
        let (task, _) = runWithHandle(
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            environment: environment,
            stdin: stdinString,
            timeout: timeout
        )
        return try await task.value
    }

    // MARK: Streaming run

    /// Runs a process and calls back on each chunk of stdout/stderr as it arrives.
    ///
    /// - Returns: The process exit code.
    ///
    /// Implementation note: we use a background thread (via `Task.detached`) to
    /// call `waitUntilExit()` so the actor thread is not blocked, and drain
    /// the pipes synchronously after the process exits to ensure all output
    /// is delivered before returning.
    public func runStreaming(
        executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        stdin stdinString: String? = nil,
        timeout: TimeInterval? = nil,
        onStdout: @Sendable @escaping (String) -> Void,
        onStderr: @Sendable @escaping (String) -> Void
    ) async throws -> Int32 {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        Self.configure(
            process: process,
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            environment: environment
        )
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let stdinString {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            if let data = stdinString.data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(data)
            }
            stdinPipe.fileHandleForWriting.closeFile()
        }

        try process.run()

        if let timeout {
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning { process.terminate() }
            }
        }

        // Drain pipes on a background thread so we don't block the actor.
        return try await Task.detached(priority: .userInitiated) {
            // readDataToEndOfFile blocks until the pipe is closed (process exits).
            let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            if !outData.isEmpty, let str = String(data: outData, encoding: .utf8) {
                onStdout(str)
            }
            if !errData.isEmpty, let str = String(data: errData, encoding: .utf8) {
                onStderr(str)
            }

            return process.terminationStatus
        }.value
    }

    // MARK: Abort handle variant

    /// Runs a process and returns both a `Task` that resolves to the result and
    /// an `AbortHandle` that can terminate the process early.
    ///
    /// - Returns: A tuple of `(task, abortHandle)`. Await `task.value` for the result.
    public nonisolated func runWithHandle(
        executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        stdin stdinString: String? = nil,
        timeout: TimeInterval? = nil
    ) -> (Task<ProcessResult, Error>, AbortHandle) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        Self.configure(
            process: process,
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            environment: environment
        )
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let stdinString {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            if let data = stdinString.data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(data)
            }
            stdinPipe.fileHandleForWriting.closeFile()
        }

        let handle = AbortHandle {
            if process.isRunning { process.terminate() }
        }

        let task = Task<ProcessResult, Error> {
            try process.run()

            if let timeout {
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if process.isRunning { process.terminate() }
                }
            }

            // Collect output (blocks until the pipe is closed)
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            try Task.checkCancellation()

            return ProcessResult(
                exitCode: process.terminationStatus,
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )
        }

        return (task, handle)
    }

    // MARK: Helpers

    private static func configure(
        process: Process,
        executable: String,
        arguments: [String],
        workingDirectory: URL?,
        environment: [String: String]?
    ) {
        if executable.hasPrefix("/") || executable.hasPrefix("./") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
        } else {
            // Resolve via env so bare names like "git", "echo" work
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
        }

        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }
        if let environment {
            process.environment = environment
        }
    }
}
