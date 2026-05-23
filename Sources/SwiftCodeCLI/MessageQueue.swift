// MessageQueue.swift
// SwiftCodeCLI
//
// A generic async FIFO queue with blocking dequeue.
// Used to buffer concurrent input and output events in the REPL.

import Foundation

// MARK: - MessageQueue

/// Thread-safe FIFO queue backed by Swift concurrency.
///
/// `dequeue()` suspends the caller until an element is available or the queue
/// is closed. Closing the queue with `close()` causes pending and future
/// `dequeue()` calls to return `nil`.
public actor MessageQueue<Element: Sendable> {

    // MARK: State

    private var buffer: [Element] = []
    private var waiters: [CheckedContinuation<Element?, Never>] = []
    private var closed: Bool = false

    // MARK: Init

    public init() {}

    // MARK: - Enqueue

    /// Add an element to the tail of the queue.
    /// No-op if the queue is already closed.
    public func enqueue(_ element: Element) {
        guard !closed else { return }

        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume(returning: element)
        } else {
            buffer.append(element)
        }
    }

    // MARK: - Dequeue

    /// Remove and return the head element, suspending until one is available.
    /// Returns `nil` if the queue is closed and empty.
    public func dequeue() async -> Element? {
        if !buffer.isEmpty {
            return buffer.removeFirst()
        }
        if closed {
            return nil
        }
        // Suspend until an element arrives or queue is closed
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    // MARK: - Close

    /// Signal that no more elements will be enqueued.
    /// All pending `dequeue()` calls return `nil`.
    public func close() {
        closed = true
        // Wake all waiters with nil
        for waiter in waiters {
            waiter.resume(returning: nil)
        }
        waiters.removeAll()
    }

    // MARK: - Inspection

    /// Number of elements currently buffered.
    public var count: Int { buffer.count }

    /// Whether the queue has been closed.
    public var isClosed: Bool { closed }
}
