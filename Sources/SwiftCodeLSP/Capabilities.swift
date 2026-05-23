/// LSP client and server capabilities.
///
/// Only the subset relevant to diagnostics and passive feedback is modeled.
/// Full LSP capabilities go well beyond what Claude Code needs.

import Foundation

// MARK: - Position / Range

public struct LSPPosition: Codable, Sendable, Equatable {
    /// Zero-based line number.
    public let line: Int
    /// Zero-based character offset.
    public let character: Int

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}

public struct LSPRange: Codable, Sendable, Equatable {
    public let start: LSPPosition
    public let end: LSPPosition

    public init(start: LSPPosition, end: LSPPosition) {
        self.start = start
        self.end = end
    }
}

// MARK: - TextDocumentItem

public struct TextDocumentItem: Codable, Sendable {
    public let uri: String
    public let languageId: String
    public let version: Int
    public let text: String

    public init(uri: String, languageId: String, version: Int, text: String) {
        self.uri = uri
        self.languageId = languageId
        self.version = version
        self.text = text
    }
}

public struct TextDocumentIdentifier: Codable, Sendable {
    public let uri: String
    public init(uri: String) { self.uri = uri }
}

public struct VersionedTextDocumentIdentifier: Codable, Sendable {
    public let uri: String
    public let version: Int
    public init(uri: String, version: Int) { self.uri = uri; self.version = version }
}

public struct TextDocumentContentChangeEvent: Codable, Sendable {
    public let range: LSPRange?
    public let text: String

    public init(range: LSPRange? = nil, text: String) {
        self.range = range
        self.text = text
    }
}

// MARK: - ClientCapabilities

/// The subset of LSP client capabilities we advertise.
public struct ClientCapabilities: Codable, Sendable {
    public struct TextDocumentClientCapabilities: Codable, Sendable {
        public struct PublishDiagnosticsClientCapabilities: Codable, Sendable {
            public let relatedInformation: Bool
            public init(relatedInformation: Bool = true) {
                self.relatedInformation = relatedInformation
            }
        }
        public let publishDiagnostics: PublishDiagnosticsClientCapabilities

        public init(publishDiagnostics: PublishDiagnosticsClientCapabilities = .init()) {
            self.publishDiagnostics = publishDiagnostics
        }
    }

    public let textDocument: TextDocumentClientCapabilities

    public init(textDocument: TextDocumentClientCapabilities = .init()) {
        self.textDocument = textDocument
    }
}

// MARK: - ServerCapabilities (LSP)

public struct LSPServerCapabilities: Codable, Sendable {
    public let textDocumentSync: TextDocumentSyncKind?
    public let hoverProvider: Bool?
    public let completionProvider: Bool?
    public let definitionProvider: Bool?
    public let referencesProvider: Bool?
    public let documentSymbolProvider: Bool?
    public let workspaceSymbolProvider: Bool?
    public let codeActionProvider: Bool?
    public let diagnosticProvider: DiagnosticOptions?

    public init(
        textDocumentSync: TextDocumentSyncKind? = nil,
        hoverProvider: Bool? = nil,
        completionProvider: Bool? = nil,
        definitionProvider: Bool? = nil,
        referencesProvider: Bool? = nil,
        documentSymbolProvider: Bool? = nil,
        workspaceSymbolProvider: Bool? = nil,
        codeActionProvider: Bool? = nil,
        diagnosticProvider: DiagnosticOptions? = nil
    ) {
        self.textDocumentSync = textDocumentSync
        self.hoverProvider = hoverProvider
        self.completionProvider = completionProvider
        self.definitionProvider = definitionProvider
        self.referencesProvider = referencesProvider
        self.documentSymbolProvider = documentSymbolProvider
        self.workspaceSymbolProvider = workspaceSymbolProvider
        self.codeActionProvider = codeActionProvider
        self.diagnosticProvider = diagnosticProvider
    }
}

public enum TextDocumentSyncKind: Int, Codable, Sendable {
    case none = 0
    case full = 1
    case incremental = 2
}

public struct DiagnosticOptions: Codable, Sendable {
    public let identifier: String?
    public let interFileDependencies: Bool
    public let workspaceDiagnostics: Bool

    public init(identifier: String? = nil, interFileDependencies: Bool = false, workspaceDiagnostics: Bool = false) {
        self.identifier = identifier
        self.interFileDependencies = interFileDependencies
        self.workspaceDiagnostics = workspaceDiagnostics
    }
}

// MARK: - InitializeResult (LSP)

public struct LSPInitializeResult: Sendable {
    public let capabilities: LSPServerCapabilities
    public let serverInfo: LSPServerInfo?

    public init(capabilities: LSPServerCapabilities, serverInfo: LSPServerInfo? = nil) {
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}

public struct LSPServerInfo: Sendable {
    public let name: String
    public let version: String?

    public init(name: String, version: String? = nil) {
        self.name = name
        self.version = version
    }
}
