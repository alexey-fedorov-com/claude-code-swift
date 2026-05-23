import XCTest
@testable import SwiftCodeCommands

/// Verifies that every command name listed in the reference (commands.ts)
/// has a corresponding entry in `CommandRegistry.allCommandNames`.
final class CommandParityTests: XCTestCase {

    /// Commands that appear in the TypeScript reference and must be registered
    /// in the Swift port (either fully implemented or as stubs).
    static let requiredCommandNames: Set<String> = [
        // Core external commands
        "add-dir", "advisor", "agents", "branch", "btw", "chrome",
        "clear", "color", "compact", "config", "context", "copy",
        "cost", "desktop", "diff", "doctor", "effort", "exit",
        "export", "fast", "feedback", "files", "heapdump", "help",
        "hooks", "ide", "init", "install-github-app", "install-slack-app",
        "keybindings", "login", "logout", "mcp", "memory", "mobile",
        "model", "output-style", "passes", "permissions", "plan",
        "plugin", "pr_comments", "privacy-settings", "rate-limit-options",
        "release-notes", "reload-plugins", "remote-env", "rename",
        "resume", "review", "rewind", "sandbox-toggle", "security-review",
        "session", "skills", "stats", "status", "statusline", "stickers",
        "tag", "tasks", "teleport", "terminalSetup", "theme",
        "thinkback", "thinkback-play", "upgrade", "usage", "vim",
        // Feature-gated
        "voice", "bridge", "buddy", "ultraplan", "assistant", "brief",
        // Internal / ant-only
        "ant-trace", "autofix-pr", "backfill-sessions", "break-cache",
        "bridge-kick", "bughunter", "commit", "commit-push-pr",
        "ctx_viz", "debug-tool-call", "env", "good-claude",
        "init-verifiers", "insights", "issue", "mock-limits",
        "oauth-refresh", "onboarding", "perf-issue", "reset-limits",
        "share", "summary", "version",
    ]

    func testAllRequiredCommandNamesArePresent() {
        let registered = Set(CommandRegistry.allCommandNames)
        let missing = Self.requiredCommandNames.subtracting(registered)
        XCTAssertTrue(
            missing.isEmpty,
            "Missing from CommandRegistry.allCommandNames: \(missing.sorted().joined(separator: ", "))"
        )
    }

    func testMinimumCommandCount() {
        // The reference has 80+ commands; we require at least 80
        XCTAssertGreaterThanOrEqual(
            CommandRegistry.allCommandNames.count, 80,
            "Expected at least 80 commands in allCommandNames"
        )
    }

    func testCoreExternalCommandsRegisteredByDefault() async throws {
        let coreNames = ["help", "clear", "exit", "model", "config", "cost", "status", "vim"]
        let registry = CommandRegistry.defaultRegistry()
        try? await Task.sleep(nanoseconds: 10_000_000)

        for name in coreNames {
            let cmd = await registry.lookup(name: name)
            XCTAssertNotNil(cmd, "/\(name) should be registered in the default registry")
        }
    }
}
