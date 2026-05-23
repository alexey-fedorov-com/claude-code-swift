import Foundation

public final class EventLoop: @unchecked Sendable {
    private let reader: InputReader
    private var thread: Thread?
    private let stopFlag = NSLock()
    private var _stopped = false
    private let onEvent: @Sendable (InputEvent) -> Void

    public init(reader: InputReader = InputReader(),
                onEvent: @escaping @Sendable (InputEvent) -> Void) {
        self.reader = reader
        self.onEvent = onEvent
    }

    public func start() {
        let r = reader
        let cb = onEvent
        let isStopped: @Sendable () -> Bool = { [weak self] in
            guard let self = self else { return true }
            self.stopFlag.lock(); defer { self.stopFlag.unlock() }
            return self._stopped
        }
        let t = Thread {
            while !isStopped() {
                if let event = r.next() {
                    cb(event)
                }
            }
        }
        t.qualityOfService = .userInteractive
        t.start()
        self.thread = t
    }

    public func stop() {
        stopFlag.lock()
        _stopped = true
        stopFlag.unlock()
        thread?.cancel()
    }
}
