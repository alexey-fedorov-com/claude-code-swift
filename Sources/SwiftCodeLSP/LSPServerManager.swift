/// LSP server lifecycle manager.
///
/// Manages multiple LSP server instances (one per language or workspace).
/// Handles start, stop, restart, and crash recovery.

import Foundation

// MARK: - LSPServerConfig

public struct LSPServerConfig: Sendable {
    public let name: String
    public let command: String
    public let args: [String]
    public let env: [String: String]?
    /// File extensions this server handles (e.g., ["swift", "swift-package"]).
    public let fileExtensions: [String]

    public init(
        name: String,
        command: String,
        args: [String] = [],
        env: [String: String]? = nil,
        fileExtensions: [String] = []
    ) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.fileExtensions = fileExtensions
    }
}

// MARK: - LSPServerState

public enum LSPServerState: Sendable {
    case stopped
    case starting
    case running(LSPInitializeResult)
    case failed(Error)
}

// MARK: - ManagedLSPServer

/// A single managed LSP server instance.
public actor ManagedLSPServer {

    public let config: LSPServerConfig
    public private(set) var state: LSPServerState = .stopped
    private var client: LSPClient?

    public init(config: LSPServerConfig) {
        self.config = config
    }

    public func start(rootURI: String) async throws {
        guard case .stopped = state else { return }
        state = .starting
        do {
            let client = LSPClient(
                serverCommand: config.command,
                serverArgs: config.args,
                serverEnv: config.env
            )
            let result = try await client.initialize(rootURI: rootURI)
            self.client = client
            state = .running(result)
        } catch {
            state = .failed(error)
            throw error
        }
    }

    public func stop() async {
        defer { state = .stopped; client = nil }
        try? await client?.shutdown()
    }

    public func restart(rootURI: String) async throws {
        await stop()
        try await start(rootURI: rootURI)
    }

    public func lspClient() -> LSPClient? { client }
}

// MARK: - LSPServerManager

/// Manages all LSP server instances for a workspace.
public actor LSPServerManager {

    private var servers: [String: ManagedLSPServer] = [:]
    private let rootURI: String

    public init(rootURI: String) {
        self.rootURI = rootURI
    }

    // MARK: Server Management

    public func addServer(config: LSPServerConfig) {
        servers[config.name] = ManagedLSPServer(config: config)
    }

    public func startAll() async {
        await withTaskGroup(of: Void.self) { group in
            for server in servers.values {
                let uri = rootURI
                group.addTask {
                    try? await server.start(rootURI: uri)
                }
            }
        }
    }

    public func stopAll() async {
        await withTaskGroup(of: Void.self) { group in
            for server in servers.values {
                group.addTask {
                    await server.stop()
                }
            }
        }
    }

    public func server(named name: String) -> ManagedLSPServer? {
        servers[name]
    }

    /// Find the server that handles a given file extension.
    public func server(for fileExtension: String) -> ManagedLSPServer? {
        servers.values.first { $0.config.fileExtensions.contains(fileExtension) }
    }

    // MARK: Convenience

    public func diagnostics(for uri: String) async -> [Diagnostic] {
        let ext = (uri as NSString).pathExtension
        guard let server = server(for: ext),
              let client = await server.lspClient() else { return [] }
        return await client.diagnostics(for: uri)
    }

    public func openDocument(uri: String, languageId: String, text: String) async {
        let ext = (uri as NSString).pathExtension
        if let server = server(for: ext),
           let client = await server.lspClient() {
            try? await client.didOpen(uri: uri, languageId: languageId, text: text)
        }
    }
}
