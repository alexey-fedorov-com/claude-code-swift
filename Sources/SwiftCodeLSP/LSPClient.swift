/// JSON-RPC 2.0 LSP client over stdio.
///
/// Uses Content-Length framing (not newline-delimited like MCP stdio).
/// Spawns a language server subprocess and communicates via its stdin/stdout.

import Foundation

// MARK: - LSPClientError

public enum LSPClientError: Error, Sendable {
    case notInitialized
    case serverError(LSPError)
    case decodingError(String)
    case timeout
    case closed
    case processExited(Int32)
}

// MARK: - LSPClient

/// Actor-isolated LSP client. Manages the server subprocess and JSON-RPC framing.
public actor LSPClient {

    // MARK: Configuration

    private let serverCommand: String
    private let serverArgs: [String]
    private let serverEnv: [String: String]?

    // MARK: State

    private var process: Process?
    private var stdinPipe: Pipe?
    private var nextId: Int = 1
    private var pendingRequests: [LSPId: CheckedContinuation<AnyCodable?, Error>] = [:]
    private var notificationHandlers: [String: @Sendable (AnyCodable?) -> Void] = [:]
    private var isRunning = false
    private var buffer = Data()
    public private(set) var diagnosticsRegistry = DiagnosticsRegistry()

    // MARK: Init

    public init(
        serverCommand: String,
        serverArgs: [String] = [],
        serverEnv: [String: String]? = nil
    ) {
        self.serverCommand = serverCommand
        self.serverArgs = serverArgs
        self.serverEnv = serverEnv
    }

    // MARK: Lifecycle

    public func initialize(
        rootURI: String,
        capabilities: ClientCapabilities = ClientCapabilities()
    ) async throws -> LSPInitializeResult {
        try await startProcess()

        let params: [String: Any] = [
            "processId": ProcessInfo.processInfo.processIdentifier,
            "rootUri": rootURI,
            "capabilities": try encodeCapabilities(capabilities)
        ]

        let result = try await sendRequest(
            method: "initialize",
            params: AnyCodable(params)
        )

        // Send initialized notification
        try await sendNotification(method: "initialized", params: AnyCodable([:] as [String: Any]))

        return parseInitializeResult(result)
    }

    // MARK: Document Sync

    public func didOpen(uri: String, languageId: String, text: String) async throws {
        let params: [String: Any] = [
            "textDocument": [
                "uri": uri,
                "languageId": languageId,
                "version": 1,
                "text": text
            ] as [String: Any]
        ]
        try await sendNotification(method: "textDocument/didOpen", params: AnyCodable(params))
    }

    public func didChange(
        uri: String,
        version: Int,
        changes: [TextDocumentContentChangeEvent]
    ) async throws {
        let changesRaw = changes.map { change -> [String: Any] in
            var dict: [String: Any] = ["text": change.text]
            if let range = change.range {
                dict["range"] = [
                    "start": ["line": range.start.line, "character": range.start.character],
                    "end": ["line": range.end.line, "character": range.end.character]
                ] as [String: Any]
            }
            return dict
        }
        let params: [String: Any] = [
            "textDocument": ["uri": uri, "version": version],
            "contentChanges": changesRaw
        ]
        try await sendNotification(method: "textDocument/didChange", params: AnyCodable(params))
    }

    public func didClose(uri: String) async throws {
        let params: [String: Any] = ["textDocument": ["uri": uri]]
        try await sendNotification(method: "textDocument/didClose", params: AnyCodable(params))
    }

    // MARK: Diagnostics

    public func diagnostics(for uri: String) async -> [Diagnostic] {
        await diagnosticsRegistry.diagnostics(for: uri)
    }

    // MARK: Shutdown

    public func shutdown() async throws {
        guard isRunning else { return }
        _ = try? await sendRequest(method: "shutdown", params: nil)
        try await sendNotification(method: "exit", params: nil)
        isRunning = false
        process?.terminate()
        process?.waitUntilExit()
        process = nil
    }

    // MARK: Notification Handlers

    public func onNotification(
        method: String,
        handler: @escaping @Sendable (AnyCodable?) -> Void
    ) {
        notificationHandlers[method] = handler
    }

    // MARK: Internal: Process

    private func startProcess() async throws {
        guard process == nil else { return }

        let proc = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        if serverCommand.hasPrefix("/") || serverCommand.hasPrefix("./") {
            proc.executableURL = URL(fileURLWithPath: serverCommand)
            proc.arguments = serverArgs
        } else {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = [serverCommand] + serverArgs
        }

        if let env = serverEnv {
            proc.environment = env
        }

        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        self.process = proc
        self.stdinPipe = stdin

        // Discard stderr
        let stderrHandle = stderr.fileHandleForReading
        Task.detached { _ = stderrHandle.readDataToEndOfFile() }

        try proc.run()
        isRunning = true

        startReadLoop(handle: stdout.fileHandleForReading)
    }

    // MARK: Internal: Send

    private func sendRequest(method: String, params: AnyCodable?) async throws -> AnyCodable? {
        let id = LSPId.number(nextId)
        nextId += 1

        let request = LSPRequest(id: id, method: method, params: params)
        let body = try JSONEncoder().encode(request)
        let framed = LSPFraming.frame(body)

        return try await withCheckedThrowingContinuation { cont in
            pendingRequests[id] = cont
            Task {
                do {
                    guard let pipe = self.stdinPipe else {
                        throw LSPClientError.notInitialized
                    }
                    try pipe.fileHandleForWriting.write(contentsOf: framed)
                } catch {
                    await self.failRequest(id: id, error: error)
                }
            }
            // 30s timeout
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await self.timeoutRequest(id: id)
            }
        }
    }

    private func sendNotification(method: String, params: AnyCodable?) async throws {
        let notif = LSPNotification(method: method, params: params)
        let body = try JSONEncoder().encode(notif)
        let framed = LSPFraming.frame(body)
        guard let pipe = stdinPipe else { throw LSPClientError.notInitialized }
        try pipe.fileHandleForWriting.write(contentsOf: framed)
    }

    private func failRequest(id: LSPId, error: Error) {
        if let cont = pendingRequests.removeValue(forKey: id) {
            cont.resume(throwing: error)
        }
    }

    private func timeoutRequest(id: LSPId) {
        if let cont = pendingRequests.removeValue(forKey: id) {
            cont.resume(throwing: LSPClientError.timeout)
        }
    }

    // MARK: Internal: Receive loop

    private func startReadLoop(handle: FileHandle) {
        Task.detached { [weak self] in
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                await self?.appendToBuffer(chunk)
            }
            await self?.handleEOF()
        }
    }

    private func appendToBuffer(_ data: Data) {
        buffer.append(data)
        while let body = LSPFraming.parse(buffer: &buffer) {
            handleMessage(body)
        }
    }

    private func handleMessage(_ body: Data) {
        // Try response
        if let response = try? JSONDecoder().decode(LSPResponse.self, from: body) {
            let id = response.id
            if let cont = pendingRequests.removeValue(forKey: id) {
                if let error = response.error {
                    cont.resume(throwing: LSPClientError.serverError(error))
                } else {
                    cont.resume(returning: response.result)
                }
            }
            return
        }
        // Try notification
        if let notif = try? JSONDecoder().decode(LSPNotification.self, from: body) {
            handleNotification(notif)
        }
    }

    private func handleNotification(_ notif: LSPNotification) {
        switch notif.method {
        case "textDocument/publishDiagnostics":
            handlePublishDiagnostics(notif.params)
        default:
            notificationHandlers[notif.method]?(notif.params)
        }
    }

    private func handlePublishDiagnostics(_ params: AnyCodable?) {
        guard let dict = params?.value as? [String: Any],
              let uri = dict["uri"] as? String,
              let diagsRaw = dict["diagnostics"] as? [[String: Any]] else { return }

        let diags = diagsRaw.compactMap { raw -> Diagnostic? in
            guard let rangeRaw = raw["range"] as? [String: Any],
                  let startRaw = rangeRaw["start"] as? [String: Any],
                  let endRaw = rangeRaw["end"] as? [String: Any],
                  let message = raw["message"] as? String else { return nil }

            let start = LSPPosition(
                line: startRaw["line"] as? Int ?? 0,
                character: startRaw["character"] as? Int ?? 0
            )
            let end = LSPPosition(
                line: endRaw["line"] as? Int ?? 0,
                character: endRaw["character"] as? Int ?? 0
            )
            let severity = (raw["severity"] as? Int).flatMap { DiagnosticSeverity(rawValue: $0) }
            return Diagnostic(
                range: LSPRange(start: start, end: end),
                severity: severity,
                code: raw["code"].flatMap { "\($0)" },
                source: raw["source"] as? String,
                message: message
            )
        }
        Task { await diagnosticsRegistry.update(uri: uri, diagnostics: diags) }
    }

    private func handleEOF() {
        isRunning = false
        let err = LSPClientError.closed
        for (_, cont) in pendingRequests {
            cont.resume(throwing: err)
        }
        pendingRequests = [:]
    }

    // MARK: Helpers

    private func encodeCapabilities(_ caps: ClientCapabilities) throws -> [String: Any] {
        let data = try JSONEncoder().encode(caps)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func parseInitializeResult(_ result: AnyCodable?) -> LSPInitializeResult {
        guard let dict = result?.value as? [String: Any],
              let capsDict = dict["capabilities"] as? [String: Any] else {
            return LSPInitializeResult(capabilities: LSPServerCapabilities())
        }

        let syncKind: TextDocumentSyncKind?
        if let raw = capsDict["textDocumentSync"] as? Int {
            syncKind = TextDocumentSyncKind(rawValue: raw)
        } else {
            syncKind = nil
        }

        let caps = LSPServerCapabilities(
            textDocumentSync: syncKind,
            hoverProvider: capsDict["hoverProvider"] as? Bool,
            completionProvider: capsDict["completionProvider"] != nil,
            definitionProvider: capsDict["definitionProvider"] as? Bool,
            referencesProvider: capsDict["referencesProvider"] as? Bool,
            documentSymbolProvider: capsDict["documentSymbolProvider"] as? Bool,
            workspaceSymbolProvider: capsDict["workspaceSymbolProvider"] as? Bool,
            codeActionProvider: capsDict["codeActionProvider"] as? Bool
        )

        var serverInfo: LSPServerInfo? = nil
        if let infoDict = dict["serverInfo"] as? [String: Any],
           let name = infoDict["name"] as? String {
            serverInfo = LSPServerInfo(name: name, version: infoDict["version"] as? String)
        }

        return LSPInitializeResult(capabilities: caps, serverInfo: serverInfo)
    }
}
