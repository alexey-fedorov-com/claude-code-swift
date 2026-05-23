/// LSP diagnostics registry.
///
/// The LSP server publishes diagnostics via `textDocument/publishDiagnostics`
/// notifications. We collect them here for use by the tools/UI.

import Foundation

// MARK: - DiagnosticSeverity

public enum DiagnosticSeverity: Int, Codable, Sendable, Comparable {
    case error = 1
    case warning = 2
    case information = 3
    case hint = 4

    public static func < (lhs: DiagnosticSeverity, rhs: DiagnosticSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Diagnostic

public struct Diagnostic: Codable, Sendable {
    public let range: LSPRange
    public let severity: DiagnosticSeverity?
    public let code: String?
    public let source: String?
    public let message: String

    public init(
        range: LSPRange,
        severity: DiagnosticSeverity? = nil,
        code: String? = nil,
        source: String? = nil,
        message: String
    ) {
        self.range = range
        self.severity = severity
        self.code = code
        self.source = source
        self.message = message
    }
}

// MARK: - DiagnosticsRegistry

/// Stores diagnostics published by an LSP server, keyed by document URI.
public actor DiagnosticsRegistry {

    private var diagnostics: [String: [Diagnostic]] = [:]

    public init() {}

    // MARK: Mutations

    /// Replace all diagnostics for a document (called on publishDiagnostics).
    public func update(uri: String, diagnostics: [Diagnostic]) {
        if diagnostics.isEmpty {
            self.diagnostics.removeValue(forKey: uri)
        } else {
            self.diagnostics[uri] = diagnostics
        }
    }

    /// Clear diagnostics for a specific document.
    public func clear(uri: String) {
        diagnostics.removeValue(forKey: uri)
    }

    /// Clear all diagnostics.
    public func clearAll() {
        diagnostics.removeAll()
    }

    // MARK: Queries

    /// All diagnostics for a document.
    public func diagnostics(for uri: String) -> [Diagnostic] {
        return diagnostics[uri] ?? []
    }

    /// All URIs that have at least one diagnostic.
    public var affectedURIs: [String] {
        Array(diagnostics.keys).sorted()
    }

    /// All errors across all documents.
    public var allErrors: [(uri: String, diagnostic: Diagnostic)] {
        var result: [(String, Diagnostic)] = []
        for (uri, diags) in diagnostics {
            for d in diags where d.severity == .error {
                result.append((uri, d))
            }
        }
        return result
    }

    /// Count of diagnostics by severity.
    public func count(severity: DiagnosticSeverity) -> Int {
        diagnostics.values.flatMap { $0 }.filter { $0.severity == severity }.count
    }

    /// Format diagnostics for a document as a readable string.
    public func formatted(uri: String) -> String {
        let diags = diagnostics(for: uri)
        guard !diags.isEmpty else { return "No diagnostics." }
        return diags.map { d in
            let sev = d.severity.map { "\($0)" } ?? "unknown"
            let loc = "\(d.range.start.line + 1):\(d.range.start.character + 1)"
            return "[\(sev)] \(loc) \(d.message)"
        }.joined(separator: "\n")
    }
}
