import XCTest

/// Tests that verify the CLI --help output contains the expected flags and subcommands.
/// These are structural parity tests — they don't compare byte-for-byte against the golden
/// (which uses Commander.js format) but ensure every key flag and subcommand is present.
final class HelpParityTests: XCTestCase {

    // MARK: - Helpers

    private static let binary: String = {
        ProcessInfo.processInfo.environment["PACKAGE_BINARY"]
            ?? "\(FileManager.default.currentDirectoryPath)/.build/debug/swiftcode"
    }()

    /// Run the binary with given arguments and return (stdout, exit code).
    private func run(_ args: [String]) throws -> (stdout: String, exit: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.binary)
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(
            data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let stderr = String(
            data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        // Combine stdout+stderr for help output since ArgumentParser can write to either
        let combined = stdout + stderr
        return (stdout: combined, exit: process.terminationStatus)
    }

    // MARK: - Root --help tests

    func testHelpExitsZero() throws {
        let (_, code) = try run(["--help"])
        XCTAssertEqual(code, 0, "--help should exit 0")
    }

    func testHelpMentionsSwiftCode() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("Swift Code"), "--help should mention 'Swift Code'")
    }

    func testHelpMentionsPrintFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("-p") || out.contains("--print"),
                      "--help should mention -p/--print flag")
    }

    func testHelpMentionsDebugFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--debug") || out.contains("-d"),
                      "--help should mention --debug/-d flag")
    }

    func testHelpMentionsModelFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--model"), "--help should mention --model flag")
    }

    func testHelpMentionsContinueFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--continue") || out.contains("-c"),
                      "--help should mention --continue/-c flag")
    }

    func testHelpMentionsResumeFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--resume") || out.contains("-r"),
                      "--help should mention --resume/-r flag")
    }

    // MARK: - Root --help: key flags from reference

    func testHelpMentionsBareFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--bare"), "--help should mention --bare flag")
    }

    func testHelpMentionsOutputFormatFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--output-format"), "--help should mention --output-format flag")
    }

    func testHelpMentionsSystemPromptFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--system-prompt"), "--help should mention --system-prompt flag")
    }

    func testHelpMentionsAllowedToolsFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("allowedTools") || out.contains("allowed-tools"),
                      "--help should mention allowedTools flag")
    }

    func testHelpMentionsMcpConfigFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--mcp-config"), "--help should mention --mcp-config flag")
    }

    func testHelpMentionsVerboseFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--verbose"), "--help should mention --verbose flag")
    }

    func testHelpMentionsSettingsFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--settings"), "--help should mention --settings flag")
    }

    func testHelpMentionsAddDirFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--add-dir"), "--help should mention --add-dir flag")
    }

    func testHelpMentionsWorktreeFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--worktree") || out.contains("-w"),
                      "--help should mention --worktree/-w flag")
    }

    func testHelpMentionsTmuxFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--tmux"), "--help should mention --tmux flag")
    }

    func testHelpMentionsDangerouslySkipPermissionsFlag() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("--dangerously-skip-permissions"),
                      "--help should mention --dangerously-skip-permissions flag")
    }

    // MARK: - Root --help: subcommands present

    func testHelpMentionsMcpSubcommand() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("mcp"), "--help should mention mcp subcommand")
    }

    func testHelpMentionsAuthSubcommand() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("auth"), "--help should mention auth subcommand")
    }

    func testHelpMentionsPluginSubcommand() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("plugin"), "--help should mention plugin subcommand")
    }

    func testHelpMentionsDoctorSubcommand() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("doctor"), "--help should mention doctor subcommand")
    }

    func testHelpMentionsInstallSubcommand() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("install"), "--help should mention install subcommand")
    }

    func testHelpMentionsUpdateSubcommand() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("update"), "--help should mention update subcommand")
    }

    func testHelpMentionsAgentsSubcommand() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("agents"), "--help should mention agents subcommand")
    }

    func testHelpMentionsSetupTokenSubcommand() throws {
        let (out, _) = try run(["--help"])
        XCTAssertTrue(out.contains("setup-token"), "--help should mention setup-token subcommand")
    }

    // MARK: - mcp subcommand help

    func testMcpHelpExitsZero() throws {
        let (_, code) = try run(["help", "mcp"])
        XCTAssertEqual(code, 0, "swiftcode help mcp should exit 0")
    }

    func testMcpHelpMentionsSubcommands() throws {
        let (out, _) = try run(["help", "mcp"])
        XCTAssertTrue(out.contains("add"), "mcp help should mention 'add' subcommand")
        XCTAssertTrue(out.contains("list"), "mcp help should mention 'list' subcommand")
        XCTAssertTrue(out.contains("remove"), "mcp help should mention 'remove' subcommand")
        XCTAssertTrue(out.contains("get"), "mcp help should mention 'get' subcommand")
        XCTAssertTrue(out.contains("serve"), "mcp help should mention 'serve' subcommand")
        XCTAssertTrue(out.contains("add-json"), "mcp help should mention 'add-json' subcommand")
        XCTAssertTrue(out.contains("add-from-claude-desktop"), "mcp help should mention 'add-from-claude-desktop' subcommand")
        XCTAssertTrue(out.contains("reset-project-choices"), "mcp help should mention 'reset-project-choices' subcommand")
    }

    // MARK: - auth subcommand help

    func testAuthHelpExitsZero() throws {
        let (_, code) = try run(["help", "auth"])
        XCTAssertEqual(code, 0, "swiftcode help auth should exit 0")
    }

    func testAuthHelpMentionsSubcommands() throws {
        let (out, _) = try run(["help", "auth"])
        XCTAssertTrue(out.contains("login"), "auth help should mention 'login'")
        XCTAssertTrue(out.contains("logout"), "auth help should mention 'logout'")
        XCTAssertTrue(out.contains("status"), "auth help should mention 'status'")
    }

    // MARK: - plugin subcommand help

    func testPluginHelpExitsZero() throws {
        let (_, code) = try run(["help", "plugin"])
        XCTAssertEqual(code, 0, "swiftcode help plugin should exit 0")
    }

    func testPluginHelpMentionsSubcommands() throws {
        let (out, _) = try run(["help", "plugin"])
        XCTAssertTrue(out.contains("install"), "plugin help should mention 'install'")
        XCTAssertTrue(out.contains("uninstall"), "plugin help should mention 'uninstall'")
        XCTAssertTrue(out.contains("list"), "plugin help should mention 'list'")
        XCTAssertTrue(out.contains("enable"), "plugin help should mention 'enable'")
        XCTAssertTrue(out.contains("disable"), "plugin help should mention 'disable'")
        XCTAssertTrue(out.contains("marketplace"), "plugin help should mention 'marketplace'")
    }

    // MARK: - version flags (parity with VersionCommandTests)

    func testVersionFlagMatchesDisplay() throws {
        let (out, code) = try run(["--version"])
        XCTAssertEqual(code, 0)
        XCTAssertTrue(out.contains("2.1.88"), "--version should contain 2.1.88")
    }

    func testShortVersionFlagMatchesDisplay() throws {
        let (out, code) = try run(["-v"])
        XCTAssertEqual(code, 0)
        XCTAssertTrue(out.contains("2.1.88"), "-v should contain 2.1.88")
    }
}
