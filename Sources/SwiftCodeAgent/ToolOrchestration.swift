// ToolOrchestration.swift
// SwiftCodeAgent
//
// Skeleton tool dispatch coordinator.
// Real tool implementations land in Task 13 (SwiftCodeTools target).
//
// Mirrors the tool dispatch pattern from:
//   .reference/src/query/*.ts  — tool invocation in the query loop
//   .reference/src/Tool.ts     — ToolUseContext, tool interface

import Foundation
import SwiftCodeCore

// MARK: - ToolHandler Protocol

/// Protocol that all concrete tool implementations must conform to.
/// Tools are registered with ToolOrchestrator and dispatched by name.
///
/// This mirrors the `Tool` interface in .reference/src/Tool.ts.
public protocol ToolHandler: Sendable {
    /// The canonical name of the tool (must match what the model sends in tool_use).
    var name: String { get }

    /// Execute the tool with the given input and return a result string.
    /// - Parameter input: The JSON-decoded input from the model.
    /// - Returns: Tool result as a string (may be multi-line).
    /// - Throws: Any error that should be reported back as a tool_result error.
    func execute(input: [String: JSONValue]) async throws -> String
}

// MARK: - ToolError

public enum ToolError: Error, Sendable {
    /// No handler registered for the requested tool name.
    case unknownTool(name: String)
    /// The tool handler threw an error.
    case executionFailed(name: String, underlying: Error)
}

// MARK: - ToolOrchestrator

/// Central registry and dispatcher for all tool handlers.
///
/// The query loop calls `dispatch(name:input:)` when the model emits a
/// `tool_use` content block. The orchestrator looks up the registered handler
/// and invokes it, returning the result string which is then wrapped into a
/// `tool_result` user message.
///
/// External modules (SwiftCodeTools, Task 13) register handlers via
/// `register(_:)`. Handlers registered after a dispatch is in flight are
/// visible to subsequent dispatches.
public actor ToolOrchestrator {

    private var handlers: [String: any ToolHandler] = [:]

    public init() {}

    // MARK: Registration

    /// Register a tool handler. Any existing handler with the same name is replaced.
    public func register(_ handler: some ToolHandler) {
        handlers[handler.name] = handler
    }

    /// Register multiple handlers at once.
    public func register(_ handlers: [any ToolHandler]) {
        for handler in handlers {
            self.handlers[handler.name] = handler
        }
    }

    /// Returns the names of all currently registered tools.
    public var registeredToolNames: [String] {
        Array(handlers.keys).sorted()
    }

    // MARK: Dispatch

    /// Dispatch a tool call to the appropriate handler.
    ///
    /// - Parameters:
    ///   - name:   The tool name from the model's `tool_use` block.
    ///   - input:  The parsed JSON input from the model.
    /// - Returns:  The tool result string to wrap in a `tool_result` message.
    /// - Throws:   `ToolError.unknownTool` if no handler is registered,
    ///             or `ToolError.executionFailed` wrapping the handler's error.
    public func dispatch(name: String, input: [String: JSONValue]) async throws -> String {
        guard let handler = handlers[name] else {
            throw ToolError.unknownTool(name: name)
        }
        do {
            return try await handler.execute(input: input)
        } catch {
            throw ToolError.executionFailed(name: name, underlying: error)
        }
    }

    /// Attempt dispatch, returning an error string instead of throwing.
    /// Used by QueryLoop to produce a `tool_result` error block when a tool fails.
    public func dispatchSafe(name: String, input: [String: JSONValue]) async -> (result: String, isError: Bool) {
        do {
            let result = try await dispatch(name: name, input: input)
            return (result, false)
        } catch ToolError.unknownTool(let toolName) {
            return ("Tool not found: \(toolName). This tool is not available in the current session.", true)
        } catch ToolError.executionFailed(let toolName, let underlying) {
            return ("Tool '\(toolName)' failed: \(underlying.localizedDescription)", true)
        } catch {
            return ("Tool '\(name)' encountered an unexpected error: \(error.localizedDescription)", true)
        }
    }
}
