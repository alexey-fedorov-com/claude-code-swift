import Darwin
import Foundation

/// Minimal one-shot HTTP/1.1 listener that captures the first GET request to
/// `/callback` and returns its query parameters.
///
/// This exists solely to receive the OAuth authorization-code redirect.
/// It binds to 127.0.0.1 on an OS-assigned port, accepts one connection,
/// reads up to ~16 KiB until end of headers, parses the request line,
/// sends a static "you can close this tab" response, and shuts down.
///
/// Designed for desktop OAuth flows where launching a real HTTP framework is
/// overkill. Uses POSIX sockets directly (Darwin only).
public actor CallbackServer {

    public struct CapturedRequest: Sendable, Equatable {
        public let path: String
        public let query: [String: String]
    }

    public enum CallbackError: Error, Sendable {
        case socketCreateFailed(errno: Int32)
        case bindFailed(errno: Int32)
        case listenFailed(errno: Int32)
        case acceptFailed(errno: Int32)
        case readFailed
        case malformedRequest
        case timedOut
    }

    private var listenFD: Int32 = -1
    private var boundPort: Int = 0

    public init() {}

    /// Bind a listening socket on `127.0.0.1` and return the assigned port.
    public func start() throws -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw CallbackError.socketCreateFailed(errno: errno) }

        // SO_REUSEADDR so a quick relaunch doesn't trip TIME_WAIT.
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = UInt16(0).bigEndian  // 0 → OS assigns port
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)

        let bindResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw CallbackError.bindFailed(errno: errno)
        }

        guard listen(fd, 1) == 0 else {
            close(fd)
            throw CallbackError.listenFailed(errno: errno)
        }

        // Read back the bound port.
        var boundAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let _ = withUnsafeMutablePointer(to: &boundAddr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                getsockname(fd, sa, &len)
            }
        }
        let port = Int(UInt16(bigEndian: boundAddr.sin_port))

        listenFD = fd
        boundPort = port
        return port
    }

    /// Block until one connection arrives, then read+parse the request.
    /// `timeoutSeconds` puts a ceiling on accept().
    public func waitForCallback(timeoutSeconds: Int = 300) async throws -> CapturedRequest {
        let fd = listenFD
        guard fd >= 0 else { throw CallbackError.acceptFailed(errno: EBADF) }

        // Use blocking accept inside a Task.detached so we don't stall the actor.
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CapturedRequest, Error>) in
            Task.detached {
                // Set a SO_RCVTIMEO via a poll() loop instead of changing socket modes.
                var pollFD = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
                let result = poll(&pollFD, 1, Int32(timeoutSeconds * 1000))
                if result == 0 {
                    cont.resume(throwing: CallbackError.timedOut)
                    return
                }
                if result < 0 {
                    cont.resume(throwing: CallbackError.acceptFailed(errno: errno))
                    return
                }

                var clientAddr = sockaddr()
                var clientLen = socklen_t(MemoryLayout<sockaddr>.size)
                let client = accept(fd, &clientAddr, &clientLen)
                if client < 0 {
                    cont.resume(throwing: CallbackError.acceptFailed(errno: errno))
                    return
                }
                defer { close(client) }

                // Read up to 16 KiB or until \r\n\r\n
                var buffer = [UInt8](repeating: 0, count: 16 * 1024)
                var total = 0
                while total < buffer.count {
                    let n = buffer.withUnsafeMutableBufferPointer { ptr -> Int in
                        let base = ptr.baseAddress!.advanced(by: total)
                        return read(client, base, ptr.count - total)
                    }
                    if n <= 0 { break }
                    total += n
                    if let _ = Self.findHeaderEnd(buffer, total) { break }
                }

                let raw = Data(buffer.prefix(total))
                guard let requestString = String(data: raw, encoding: .utf8) else {
                    Self.writeResponse(client, body: "Bad request")
                    cont.resume(throwing: CallbackError.malformedRequest)
                    return
                }

                guard let (path, query) = Self.parseRequestLine(requestString) else {
                    Self.writeResponse(client, body: "Bad request")
                    cont.resume(throwing: CallbackError.malformedRequest)
                    return
                }

                let html = """
                <html><head><title>Swift Code</title></head>
                <body style="font-family: -apple-system, sans-serif; padding: 40px; text-align: center;">
                <h2>Signed in to Swift Code</h2>
                <p>You can close this tab and return to your terminal.</p>
                </body></html>
                """
                Self.writeResponse(client, body: html, contentType: "text/html; charset=utf-8")
                cont.resume(returning: CapturedRequest(path: path, query: query))
            }
        }
    }

    /// Close the listening socket.
    public func stop() {
        if listenFD >= 0 {
            close(listenFD)
            listenFD = -1
        }
    }

    deinit {
        if listenFD >= 0 {
            close(listenFD)
        }
    }

    // MARK: - Parsing

    private static func findHeaderEnd(_ buf: [UInt8], _ count: Int) -> Int? {
        guard count >= 4 else { return nil }
        for i in 0...(count - 4) {
            if buf[i] == 0x0D, buf[i+1] == 0x0A, buf[i+2] == 0x0D, buf[i+3] == 0x0A {
                return i + 4
            }
        }
        return nil
    }

    /// Parses "GET /callback?code=abc&state=xyz HTTP/1.1" into (path, query).
    static func parseRequestLine(_ s: String) -> (String, [String: String])? {
        guard let firstLine = s.split(separator: "\r\n").first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let target = String(parts[1])

        let splitIdx = target.firstIndex(of: "?")
        let path = String(target[..<(splitIdx ?? target.endIndex)])
        var query: [String: String] = [:]
        if let i = splitIdx {
            let qs = target[target.index(after: i)...]
            for pair in qs.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    let k = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                    let v = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                    query[k] = v
                } else if kv.count == 1 {
                    query[String(kv[0])] = ""
                }
            }
        }
        return (path, query)
    }

    private static func writeResponse(
        _ fd: Int32,
        body: String,
        contentType: String = "text/plain; charset=utf-8"
    ) {
        let bodyBytes = Array(body.utf8)
        let header = """
        HTTP/1.1 200 OK\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyBytes.count)\r
        Connection: close\r
        \r

        """
        let headerBytes = Array(header.utf8)
        _ = headerBytes.withUnsafeBufferPointer { ptr in
            write(fd, ptr.baseAddress, ptr.count)
        }
        _ = bodyBytes.withUnsafeBufferPointer { ptr in
            write(fd, ptr.baseAddress, ptr.count)
        }
    }
}
