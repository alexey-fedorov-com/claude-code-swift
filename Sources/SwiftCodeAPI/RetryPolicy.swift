import Foundation

// MARK: - APIError

/// Structured errors returned from the Anthropic API.
/// Maps to the error shapes documented in the Anthropic API reference.
public enum APIError: Error, Sendable {
    case httpError(statusCode: Int, message: String?)
    case networkError(underlying: any Error)
    case decodingError(underlying: any Error)
    case authError(message: String)
    case overloaded
    case rateLimited(retryAfter: TimeInterval?)
    case unknown(message: String)

    /// User-visible description matching the reference withRetry.ts messages.
    public var userMessage: String {
        switch self {
        case .httpError(let code, let msg):
            switch code {
            case 401: return "Authentication failed. Check your API key."
            case 403: return "Permission denied."
            case 429: return "Rate limited. Please wait before retrying."
            case 500: return "Anthropic server error. Please try again."
            case 529: return "API overloaded. Please try again later."
            default:  return msg ?? "HTTP error \(code)"
            }
        case .networkError:
            return "Network error. Check your connection."
        case .decodingError:
            return "Failed to parse API response."
        case .authError(let msg):
            return "Authentication error: \(msg)"
        case .overloaded:
            return "API overloaded. Please try again later."
        case .rateLimited(let after):
            if let after = after {
                return "Rate limited. Retry after \(Int(after))s."
            }
            return "Rate limited. Please wait before retrying."
        case .unknown(let msg):
            return "Unexpected error: \(msg)"
        }
    }
}

// MARK: - RetryPolicy

/// Exponential backoff + jitter retry policy.
/// Matches the reference `withRetry.ts` logic for determining which errors are retryable.
public struct RetryPolicy: Sendable {

    /// Maximum total attempts (1 = no retries).
    public let maxAttempts: Int
    /// Initial delay in seconds before first retry.
    public let baseDelay: TimeInterval
    /// Maximum delay cap in seconds.
    public let maxDelay: TimeInterval
    /// Jitter fraction in [0, 1]: delay is multiplied by (1 ± jitter/2).
    public let jitter: Double

    public init(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        jitter: Double = 0.25
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    // MARK: Default Policies

    /// Standard policy matching the reference defaults.
    public static let `default` = RetryPolicy(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 60.0,
        jitter: 0.25
    )

    /// Aggressive policy for idempotent read-only calls.
    public static let aggressive = RetryPolicy(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 30.0,
        jitter: 0.3
    )

    /// No retries — used when the caller handles retry themselves.
    public static let noRetry = RetryPolicy(
        maxAttempts: 1,
        baseDelay: 0,
        maxDelay: 0,
        jitter: 0
    )

    // MARK: Delay Calculation

    /// Compute the delay (in seconds) before the given attempt number.
    /// `attempt` is 1-based (attempt 1 = first retry after initial failure).
    public func delay(attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        // Exponential: baseDelay * 2^(attempt-1)
        let exp = pow(2.0, Double(attempt - 1))
        let raw = min(baseDelay * exp, maxDelay)
        // Apply symmetric jitter: raw * (1 ± jitter/2)
        let jitterRange = raw * jitter
        let jittered = raw + Double.random(in: -jitterRange / 2 ..< jitterRange / 2)
        return max(0, min(jittered, maxDelay))
    }

    // MARK: Retry Decision

    /// Returns true if the given error should trigger a retry.
    public func shouldRetry(error: Error) -> Bool {
        switch error {
        case let apiErr as APIError:
            return isRetryableAPIError(apiErr)
        default:
            // Network-level errors (connection reset, timeout) are retryable
            return isRetryableNSError(error)
        }
    }

    // MARK: Private

    private func isRetryableAPIError(_ error: APIError) -> Bool {
        switch error {
        case .httpError(let code, _):
            // 429 (rate limit), 500, 502, 503, 529 (overloaded)
            return code == 429 || (code >= 500 && code != 501)
        case .networkError:
            return true
        case .overloaded:
            return true
        case .rateLimited:
            return true
        case .authError, .decodingError, .unknown:
            return false
        }
    }

    private func isRetryableNSError(_ error: Error) -> Bool {
        let nsErr = error as NSError
        // URLError / NIO connection errors
        let retryableCodes: Set<Int> = [
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorCannotConnectToHost,
            NSURLErrorDNSLookupFailed,
        ]
        return retryableCodes.contains(nsErr.code)
    }
}

// MARK: - RetryExecutor

/// Executes a throwing async closure with automatic retries according to a `RetryPolicy`.
public enum RetryExecutor {

    /// Run `operation` up to `policy.maxAttempts` times.
    /// Delays between retries using the policy's backoff schedule.
    public static func execute<T: Sendable>(
        policy: RetryPolicy = .default,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 1...policy.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                let isLastAttempt = attempt == policy.maxAttempts
                if isLastAttempt || !policy.shouldRetry(error: error) {
                    throw error
                }
                let waitSeconds = policy.delay(attempt: attempt)
                if waitSeconds > 0 {
                    try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
                }
            }
        }
        throw lastError!  // unreachable, but appeases the compiler
    }
}
