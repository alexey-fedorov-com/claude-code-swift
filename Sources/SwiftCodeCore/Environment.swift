// MARK: - Environment
// Ported from .reference/src/utils/env.ts
//
// Provides minimal environment detection utilities. The TypeScript version
// uses Node.js process.env / process.platform. In Swift we use
// ProcessInfo.processInfo.

import Foundation

// MARK: - Platform

public enum Platform: String, Sendable {
    case darwin, linux, win32
}

// MARK: - UserType

/// Which Anthropic user type this build targets.
/// Source: `process.env.USER_TYPE` in the TypeScript reference.
public enum UserType: String, Sendable {
    case external
    case ant
}

// MARK: - Environment

/// Session-stable environment snapshot. Cached on first access.
public struct Environment: Sendable {
    // MARK: Platform

    public let platform: Platform

    // MARK: Process

    public let arch: String
    public let isCI: Bool

    // MARK: User type

    public let userType: UserType

    // MARK: Demo mode

    public let isDemoMode: Bool

    // MARK: Terminal

    public let termProgram: String?
    public let isSSH: Bool

    // MARK: - Init

    public init() {
        let env = ProcessInfo.processInfo.environment

        #if os(macOS)
        self.platform = .darwin
        #elseif os(Linux)
        self.platform = .linux
        #else
        self.platform = .linux
        #endif

        #if arch(arm64)
        self.arch = "arm64"
        #elseif arch(x86_64)
        self.arch = "x86_64"
        #else
        self.arch = "unknown"
        #endif

        self.isCI = env["CI"].map { !$0.isEmpty && $0 != "0" && $0 != "false" } ?? false

        self.userType = env["USER_TYPE"] == "ant" ? .ant : .external

        self.isDemoMode = env["CLAUDE_CODE_IS_DEMO"].map {
            !$0.isEmpty && $0 != "0" && $0 != "false"
        } ?? false

        self.termProgram = env["TERM_PROGRAM"]

        self.isSSH = env["SSH_CONNECTION"] != nil
            || env["SSH_CLIENT"] != nil
            || env["SSH_TTY"] != nil
    }
}

// MARK: - Shared instance

extension Environment {
    /// Session-stable cached instance. Equivalent to the `env` export in env.ts.
    public static let current = Environment()
}

// MARK: - isEnvTruthy helper

/// Returns true when the env var is set and not falsy ("0", "false", "").
public func isEnvTruthy(_ value: String?) -> Bool {
    guard let value, !value.isEmpty else { return false }
    return value != "0" && value.lowercased() != "false"
}
