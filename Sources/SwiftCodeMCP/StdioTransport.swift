/// Stdio transport — spawn a subprocess and communicate over its stdin/stdout.
///
/// Protocol: newline-delimited JSON (one JSON object per line).
/// This is the canonical MCP transport for local servers.

import Foundation
import SwiftCodeNative

// MARK: - StdioTransport

/// Spawns an MCP server subprocess and communicates via stdin/stdout.
public actor StdioTransport: Transport {

    // MARK: Configuration

    private let command: String
    private let arguments: [String]
    private let env: [String: String]?

    // MARK: State

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutHandle: FileHandle?
    private var lineBuffer: [Data] = []
    private var continuation: CheckedContinuation<Data, Error>?
    private var isClosed = false

    // MARK: Init

    public init(command: String, arguments: [String] = [], env: [String: String]? = nil) {
        self.command = command
        self.arguments = arguments
        self.env = env
    }

    // MARK: Transport

    public func start() async throws {
        guard process == nil else { return }

        let proc = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        // Configure executable
        if command.hasPrefix("/") || command.hasPrefix("./") {
            proc.executableURL = URL(fileURLWithPath: command)
            proc.arguments = arguments
        } else {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = [command] + arguments
        }

        if let env {
            proc.environment = env
        }

        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutHandle = stdout.fileHandleForReading

        // Discard stderr in background
        let stderrHandle = stderr.fileHandleForReading
        Task.detached {
            _ = stderrHandle.readDataToEndOfFile()
        }

        try proc.run()

        // Start reading stdout line by line
        startReadLoop(handle: stdout.fileHandleForReading)
    }

    public func send(_ message: Data) async throws {
        guard let pipe = stdinPipe, !isClosed else {
            throw TransportError.notConnected
        }
        var payload = message
        payload.append(0x0A)  // newline delimiter
        try pipe.fileHandleForWriting.write(contentsOf: payload)
    }

    public func receive() async throws -> Data {
        // If we already have buffered lines, return one immediately
        if !lineBuffer.isEmpty {
            return lineBuffer.removeFirst()
        }
        // Otherwise wait for the read loop to deliver one
        return try await withCheckedThrowingContinuation { cont in
            if isClosed {
                cont.resume(throwing: TransportError.connectionClosed)
                return
            }
            self.continuation = cont
        }
    }

    public func close() async {
        guard !isClosed else { return }
        isClosed = true
        stdinPipe?.fileHandleForWriting.closeFile()
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        continuation?.resume(throwing: TransportError.connectionClosed)
        continuation = nil
    }

    // MARK: Read Loop

    private func startReadLoop(handle: FileHandle) {
        Task.detached { [weak self] in
            var buffer = Data()
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }  // EOF / process exited
                buffer.append(chunk)
                // Split on newlines
                while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let line = buffer[..<newlineIndex]
                    buffer = buffer[buffer.index(after: newlineIndex)...]
                    let lineData = Data(line)
                    guard !lineData.isEmpty else { continue }
                    await self?.deliverLine(lineData)
                }
            }
            await self?.handleEOF()
        }
    }

    private func deliverLine(_ data: Data) {
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: data)
        } else {
            lineBuffer.append(data)
        }
    }

    private func handleEOF() {
        isClosed = true
        if let cont = continuation {
            continuation = nil
            cont.resume(throwing: TransportError.connectionClosed)
        }
    }
}
