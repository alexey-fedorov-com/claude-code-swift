// MARK: - AppStateStore
// Ported from .reference/src/state/store.ts (generic Store<T>) and
// .reference/src/state/AppStateStore.ts (AppStateStore = Store<AppState>).
//
// The TypeScript version uses React's useSyncExternalStore. In Swift we
// use a simple observer pattern with @Sendable closures.

import Foundation

// MARK: - Store

/// Generic observable store — mirrors the TypeScript Store<T> shape.
/// Thread-safety: all mutations are serialized via a DispatchQueue.
public final class Store<State: Sendable>: @unchecked Sendable {
    public typealias Listener = @Sendable () -> Void
    public typealias OnChange = @Sendable (_ newState: State, _ oldState: State) -> Void

    private var state: State
    private var listeners: [UUID: Listener] = [:]
    private let queue = DispatchQueue(label: "com.swiftcode.store", attributes: .concurrent)
    private let onChange: OnChange?

    public init(initialState: State, onChange: OnChange? = nil) {
        self.state = initialState
        self.onChange = onChange
    }

    public func getState() -> State {
        queue.sync { state }
    }

    /// Update state. If the updater returns the same reference (value-equal via a custom check),
    /// listeners are not notified. For struct State, every setState call notifies (no Object.is equivalent).
    public func setState(_ updater: @Sendable (State) -> State) {
        queue.sync(flags: .barrier) {
            let prev = state
            let next = updater(prev)
            state = next
            onChange?(next, prev)
            for listener in listeners.values {
                listener()
            }
        }
    }

    /// Subscribe to state changes. Returns an unsubscribe closure.
    @discardableResult
    public func subscribe(_ listener: @escaping Listener) -> @Sendable () -> Void {
        let id = UUID()
        queue.sync(flags: .barrier) {
            listeners[id] = listener
        }
        return { [weak self] in
            guard let self else { return }
            _ = self.queue.sync(flags: .barrier) {
                self.listeners.removeValue(forKey: id)
            }
        }
    }
}

// MARK: - AppStateStore

/// Concrete store for AppState. Matches TypeScript `AppStateStore = Store<AppState>`.
public typealias AppStateStore = Store<AppState>

// MARK: - CompletionBoundary
// Ported from .reference/src/state/AppStateStore.ts

public enum CompletionBoundary: Sendable {
    case complete(completedAt: Double, outputTokens: Int)
    case bash(command: String, completedAt: Double)
    case edit(toolName: String, filePath: String, completedAt: Double)
    case deniedTool(toolName: String, detail: String, completedAt: Double)
}

// MARK: - SpeculationState
// Simplified port — drops mutable refs (not needed before Task 12).

public enum SpeculationState: Sendable {
    case idle
    case active(id: String, startTime: Double)
}

public let idleSpeculationState: SpeculationState = .idle
