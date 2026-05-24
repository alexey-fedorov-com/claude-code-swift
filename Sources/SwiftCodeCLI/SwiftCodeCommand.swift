import ArgumentParser
import Foundation
import SwiftCodeCore
import SwiftCodeAPI
import SwiftCodeAgent
import SwiftCodeCommands

public struct SwiftCodeCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "swiftcode",
        abstract: "Swift Code - starts an interactive session by default, use -p/--print for non-interactive output",
        version: SwiftCodeVersion.display,
        subcommands: [
            AgentsCommand.self,
            AuthCommand.self,
            AutoModeCommand.self,
            AssistantCommand.self,
            CompletionCommand.self,
            DoctorCommand.self,
            InstallCommand.self,
            MCPCommand.self,
            OpenCommand.self,
            PluginCommand.self,
            RemoteControlCommand.self,
            ServerCommand.self,
            SetupTokenCommand.self,
            SSHCommand.self,
            TaskCommand.self,
            UpdateCommand.self,
        ]
    )

    // -------------------------------------------------------------------------
    // Positional argument
    // -------------------------------------------------------------------------

    @Argument(help: "Your prompt")
    public var prompt: String?

    // -------------------------------------------------------------------------
    // Version (short -v alias — ArgumentParser handles --version via version: param)
    // -------------------------------------------------------------------------

    @Flag(name: .customShort("v"), help: "Output the version number")
    public var showVersion: Bool = false

    // -------------------------------------------------------------------------
    // Debug / verbosity
    // -------------------------------------------------------------------------

    /// -d, --debug [filter] — optional filter value; modelled as Optional<String>
    /// Note: ArgumentParser doesn't natively support optional-value options.
    /// We model as --debug <filter> with no default (omit for bare debug mode).
    @Option(name: [.customShort("d"), .customLong("debug")], help: "Enable debug mode with optional category filtering (e.g., \"api,hooks\" or \"!1p,!file\")")
    public var debug: String?

    /// --debug-to-stderr (hidden in reference)
    @Flag(name: .customLong("debug-to-stderr"), help: .hidden)
    public var debugToStderr: Bool = false

    @Option(name: .customLong("debug-file"), help: "Write debug logs to a specific file path (implicitly enables debug mode)")
    public var debugFile: String?

    @Flag(name: .customLong("verbose"), help: "Override verbose mode setting from config")
    public var verbose: Bool = false

    // -------------------------------------------------------------------------
    // Core output / interaction mode
    // -------------------------------------------------------------------------

    @Flag(name: [.customShort("p"), .customLong("print")],
          help: "Print response and exit (useful for pipes). Note: The workspace trust dialog is skipped when Swift Code is run with the -p mode. Only use this flag in directories you trust.")
    public var printMode: Bool = false

    @Flag(name: .customLong("bare"),
          help: "Minimal mode: skip hooks, LSP, plugin sync, attribution, auto-memory, background prefetches, keychain reads, and CLAUDE.md auto-discovery. Sets CLAUDE_CODE_SIMPLE=1. Anthropic auth is strictly ANTHROPIC_API_KEY or apiKeyHelper via --settings (OAuth and keychain are never read). 3P providers (Bedrock/Vertex/Foundry) use their own credentials. Skills still resolve via /skill-name. Explicitly provide context via: --system-prompt[-file], --append-system-prompt[-file], --add-dir (CLAUDE.md dirs), --mcp-config, --settings, --agents, --plugin-dir.")
    public var bare: Bool = false

    // hidden
    @Flag(name: .customLong("init"), help: .hidden)
    public var initFlag: Bool = false

    // hidden
    @Flag(name: .customLong("init-only"), help: .hidden)
    public var initOnly: Bool = false

    // hidden
    @Flag(name: .customLong("maintenance"), help: .hidden)
    public var maintenance: Bool = false

    // -------------------------------------------------------------------------
    // Output format
    // -------------------------------------------------------------------------

    @Option(name: .customLong("output-format"),
            help: "Output format (only works with --print): \"text\" (default), \"json\" (single result), or \"stream-json\" (realtime streaming)")
    public var outputFormat: String?

    @Option(name: .customLong("json-schema"),
            help: "JSON Schema for structured output validation. Example: {\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}")
    public var jsonSchema: String?

    @Flag(name: .customLong("include-hook-events"),
          help: "Include all hook lifecycle events in the output stream (only works with --output-format=stream-json)")
    public var includeHookEvents: Bool = false

    @Flag(name: .customLong("include-partial-messages"),
          help: "Include partial message chunks as they arrive (only works with --print and --output-format=stream-json)")
    public var includePartialMessages: Bool = false

    @Option(name: .customLong("input-format"),
            help: "Input format (only works with --print): \"text\" (default), or \"stream-json\" (realtime streaming input)")
    public var inputFormat: String?

    @Flag(name: .customLong("replay-user-messages"),
          help: "Re-emit user messages from stdin back on stdout for acknowledgment (only works with --input-format=stream-json and --output-format=stream-json)")
    public var replayUserMessages: Bool = false

    // hidden
    @Flag(name: .customLong("enable-auth-status"), help: .hidden)
    public var enableAuthStatus: Bool = false

    // -------------------------------------------------------------------------
    // Permissions
    // -------------------------------------------------------------------------

    @Flag(name: .customLong("dangerously-skip-permissions"),
          help: "Bypass all permission checks. Recommended only for sandboxes with no internet access.")
    public var dangerouslySkipPermissions: Bool = false

    @Flag(name: .customLong("allow-dangerously-skip-permissions"),
          help: "Enable bypassing all permission checks as an option, without it being enabled by default. Recommended only for sandboxes with no internet access.")
    public var allowDangerouslySkipPermissions: Bool = false

    @Option(name: .customLong("permission-mode"),
            help: "Permission mode to use for the session")
    public var permissionMode: String?

    // -------------------------------------------------------------------------
    // Thinking / budget
    // -------------------------------------------------------------------------

    // hidden
    @Option(name: .customLong("thinking"), help: .hidden)
    public var thinking: String?

    // hidden
    @Option(name: .customLong("max-thinking-tokens"), help: .hidden)
    public var maxThinkingTokens: Int?

    // hidden
    @Option(name: .customLong("max-turns"), help: .hidden)
    public var maxTurns: Int?

    // hidden
    @Option(name: .customLong("max-budget-usd"), help: .hidden)
    public var maxBudgetUsd: Double?

    // hidden
    @Option(name: .customLong("task-budget"), help: .hidden)
    public var taskBudget: Int?

    // -------------------------------------------------------------------------
    // Tools
    // -------------------------------------------------------------------------

    @Option(name: .customLong("allowedTools"), parsing: .upToNextOption,
            help: "Comma or space-separated list of tool names to allow (e.g. \"Bash(git:*) Edit\")")
    public var allowedTools: [String] = []

    @Option(name: .customLong("allowed-tools"), parsing: .upToNextOption, help: .hidden)
    public var allowedToolsAlias: [String] = []

    @Option(name: .customLong("tools"), parsing: .upToNextOption,
            help: "Specify the list of available tools from the built-in set. Use \"\" to disable all tools, \"default\" to use all tools, or specify tool names (e.g. \"Bash,Edit,Read\").")
    public var tools: [String] = []

    @Option(name: .customLong("disallowedTools"), parsing: .upToNextOption,
            help: "Comma or space-separated list of tool names to deny (e.g. \"Bash(git:*) Edit\")")
    public var disallowedTools: [String] = []

    @Option(name: .customLong("disallowed-tools"), parsing: .upToNextOption, help: .hidden)
    public var disallowedToolsAlias: [String] = []

    // hidden
    @Option(name: .customLong("permission-prompt-tool"), help: .hidden)
    public var permissionPromptTool: String?

    // -------------------------------------------------------------------------
    // MCP
    // -------------------------------------------------------------------------

    @Option(name: .customLong("mcp-config"), parsing: .upToNextOption,
            help: "Load MCP servers from JSON files or strings (space-separated)")
    public var mcpConfig: [String] = []

    @Flag(name: .customLong("mcp-debug"),
          help: "[DEPRECATED. Use --debug instead] Enable MCP debug mode (shows MCP server errors)")
    public var mcpDebug: Bool = false

    @Flag(name: .customLong("strict-mcp-config"),
          help: "Only use MCP servers from --mcp-config, ignoring all other MCP configurations")
    public var strictMcpConfig: Bool = false

    // -------------------------------------------------------------------------
    // System prompt
    // -------------------------------------------------------------------------

    @Option(name: .customLong("system-prompt"), help: "System prompt to use for the session")
    public var systemPrompt: String?

    // hidden
    @Option(name: .customLong("system-prompt-file"), help: .hidden)
    public var systemPromptFile: String?

    @Option(name: .customLong("append-system-prompt"), help: "Append a system prompt to the default system prompt")
    public var appendSystemPrompt: String?

    // hidden
    @Option(name: .customLong("append-system-prompt-file"), help: .hidden)
    public var appendSystemPromptFile: String?

    // -------------------------------------------------------------------------
    // Session / resume
    // -------------------------------------------------------------------------

    @Flag(name: [.customShort("c"), .customLong("continue")],
          help: "Continue the most recent conversation in the current directory")
    public var continueSession: Bool = false

    /// -r, --resume [value] — Optional<String>; bare -r means "open picker"
    @Option(name: [.customShort("r"), .customLong("resume")],
            help: "Resume a conversation by session ID, or open interactive picker with optional search term")
    public var resume: String?

    @Flag(name: .customLong("fork-session"),
          help: "When resuming, create a new session ID instead of reusing the original (use with --resume or --continue)")
    public var forkSession: Bool = false

    @Option(name: .customLong("from-pr"),
            help: "Resume a session linked to a PR by PR number/URL, or open interactive picker with optional search term")
    public var fromPr: String?

    @Flag(name: .customLong("no-session-persistence"),
          help: "Disable session persistence - sessions will not be saved to disk and cannot be resumed (only works with --print)")
    public var noSessionPersistence: Bool = false

    @Option(name: .customLong("session-id"), help: "Use a specific session ID for the conversation (must be a valid UUID)")
    public var sessionId: String?

    @Option(name: [.customShort("n"), .customLong("name")], help: "Set a display name for this session (shown in /resume and terminal title)")
    public var name: String?

    // hidden
    @Option(name: .customLong("resume-session-at"), help: .hidden)
    public var resumeSessionAt: String?

    // hidden
    @Option(name: .customLong("rewind-files"), help: .hidden)
    public var rewindFiles: String?

    // hidden
    @Option(name: .customLong("prefill"), help: .hidden)
    public var prefill: String?

    // hidden
    @Flag(name: .customLong("deep-link-origin"), help: .hidden)
    public var deepLinkOrigin: Bool = false

    // hidden
    @Option(name: .customLong("deep-link-repo"), help: .hidden)
    public var deepLinkRepo: String?

    // hidden
    @Option(name: .customLong("deep-link-last-fetch"), help: .hidden)
    public var deepLinkLastFetch: String?

    // -------------------------------------------------------------------------
    // Model / effort / agent
    // -------------------------------------------------------------------------

    @Option(name: .customLong("model"),
            help: "Model for the current session. Provide an alias for the latest model (e.g. 'sonnet' or 'opus') or a model's full name (e.g. 'claude-sonnet-4-6').")
    public var model: String?

    @Option(name: .customLong("effort"), help: "Effort level for the current session (low, medium, high, max)")
    public var effort: String?

    @Option(name: .customLong("agent"), help: "Agent for the current session. Overrides the 'agent' setting.")
    public var agent: String?

    @Option(name: .customLong("agents"), help: "JSON object defining custom agents (e.g. '{\"reviewer\": {\"description\": \"Reviews code\", \"prompt\": \"You are a code reviewer\"}}')")
    public var agentsJson: String?

    @Option(name: .customLong("betas"), parsing: .upToNextOption, help: "Beta headers to include in API requests (API key users only)")
    public var betas: [String] = []

    @Option(name: .customLong("fallback-model"), help: "Enable automatic fallback to specified model when default model is overloaded (only works with --print)")
    public var fallbackModel: String?

    // hidden
    @Option(name: .customLong("workload"), help: .hidden)
    public var workload: String?

    // -------------------------------------------------------------------------
    // Settings / directories
    // -------------------------------------------------------------------------

    @Option(name: .customLong("settings"), help: "Path to a settings JSON file or a JSON string to load additional settings from")
    public var settings: String?

    @Option(name: .customLong("add-dir"), parsing: .upToNextOption, help: "Additional directories to allow tool access to")
    public var addDir: [String] = []

    @Option(name: .customLong("setting-sources"), help: "Comma-separated list of setting sources to load (user, project, local).")
    public var settingSources: String?

    // hidden
    @Option(name: .customLong("flag-settings-path"), help: .hidden)
    public var flagSettingsPath: String?

    // -------------------------------------------------------------------------
    // IDE / plugins
    // -------------------------------------------------------------------------

    @Flag(name: .customLong("ide"), help: "Automatically connect to IDE on startup if exactly one valid IDE is available")
    public var ide: Bool = false

    @Option(name: .customLong("plugin-dir"), parsing: .upToNextOption,
            help: "Load plugins from a directory for this session only (repeatable: --plugin-dir A --plugin-dir B)")
    public var pluginDir: [String] = []

    @Flag(name: .customLong("disable-slash-commands"), help: "Disable all skills")
    public var disableSlashCommands: Bool = false

    // -------------------------------------------------------------------------
    // Chrome integration
    // -------------------------------------------------------------------------

    @Flag(name: .customLong("chrome"), help: "Enable Claude in Chrome integration")
    public var chrome: Bool = false

    @Flag(name: .customLong("no-chrome"), help: "Disable Claude in Chrome integration")
    public var noChrome: Bool = false

    // -------------------------------------------------------------------------
    // File resources
    // -------------------------------------------------------------------------

    @Option(name: .customLong("file"), parsing: .upToNextOption,
            help: "File resources to download at startup. Format: file_id:relative_path (e.g., --file file_abc:doc.txt file_def:img.png)")
    public var file: [String] = []

    // -------------------------------------------------------------------------
    // Worktree
    // -------------------------------------------------------------------------

    @Option(name: [.customShort("w"), .customLong("worktree")],
            help: "Create a new git worktree for this session (optionally specify a name)")
    public var worktree: String?

    @Flag(name: .customLong("tmux"),
          help: "Create a tmux session for the worktree (requires --worktree). Uses iTerm2 native panes when available; use --tmux=classic for traditional tmux.")
    public var tmux: Bool = false

    // -------------------------------------------------------------------------
    // Hidden ANT-ONLY / feature-gated flags
    // -------------------------------------------------------------------------

    // hidden: --advisor <model>
    @Option(name: .customLong("advisor"), help: .hidden)
    public var advisor: String?

    // hidden: --delegate-permissions
    @Flag(name: .customLong("delegate-permissions"), help: .hidden)
    public var delegatePermissions: Bool = false

    // hidden: --dangerously-skip-permissions-with-classifiers
    @Flag(name: .customLong("dangerously-skip-permissions-with-classifiers"), help: .hidden)
    public var dangerouslySkipPermissionsWithClassifiers: Bool = false

    // hidden: --afk
    @Flag(name: .customLong("afk"), help: .hidden)
    public var afk: Bool = false

    // hidden: --tasks [id]
    @Option(name: .customLong("tasks"), help: .hidden)
    public var tasks: String?

    // hidden: --agent-teams
    @Flag(name: .customLong("agent-teams"), help: .hidden)
    public var agentTeams: Bool = false

    // hidden: --enable-auto-mode
    @Flag(name: .customLong("enable-auto-mode"), help: .hidden)
    public var enableAutoMode: Bool = false

    // hidden: --proactive
    @Flag(name: .customLong("proactive"), help: .hidden)
    public var proactive: Bool = false

    // hidden: --messaging-socket-path <path>
    @Option(name: .customLong("messaging-socket-path"), help: .hidden)
    public var messagingSocketPath: String?

    // hidden: --brief
    @Flag(name: .customLong("brief"), help: .hidden)
    public var brief: Bool = false

    // hidden: --assistant
    @Flag(name: .customLong("assistant"), help: .hidden)
    public var assistantFlag: Bool = false

    // hidden: --channels <servers...>
    @Option(name: .customLong("channels"), parsing: .upToNextOption, help: .hidden)
    public var channels: [String] = []

    // hidden: --dangerously-load-development-channels <servers...>
    @Option(name: .customLong("dangerously-load-development-channels"), parsing: .upToNextOption, help: .hidden)
    public var dangerouslyLoadDevelopmentChannels: [String] = []

    // hidden: --agent-id <id>
    @Option(name: .customLong("agent-id"), help: .hidden)
    public var agentId: String?

    // hidden: --agent-name <name>
    @Option(name: .customLong("agent-name"), help: .hidden)
    public var agentName: String?

    // hidden: --team-name <name>
    @Option(name: .customLong("team-name"), help: .hidden)
    public var teamName: String?

    // hidden: --agent-color <color>
    @Option(name: .customLong("agent-color"), help: .hidden)
    public var agentColor: String?

    // hidden: --plan-mode-required
    @Flag(name: .customLong("plan-mode-required"), help: .hidden)
    public var planModeRequired: Bool = false

    // hidden: --parent-session-id <id>
    @Option(name: .customLong("parent-session-id"), help: .hidden)
    public var parentSessionId: String?

    // hidden: --teammate-mode <mode>
    @Option(name: .customLong("teammate-mode"), help: .hidden)
    public var teammateMode: String?

    // hidden: --agent-type <type>
    @Option(name: .customLong("agent-type"), help: .hidden)
    public var agentType: String?

    // hidden: --sdk-url <url>
    @Option(name: .customLong("sdk-url"), help: .hidden)
    public var sdkUrl: String?

    // hidden: --teleport [session]
    @Option(name: .customLong("teleport"), help: .hidden)
    public var teleport: String?

    // hidden: --remote [description]
    @Option(name: .customLong("remote"), help: .hidden)
    public var remoteFlag: String?

    // hidden: --remote-control [name]
    @Option(name: .customLong("remote-control"), help: .hidden)
    public var remoteControl: String?

    // hidden: --rc [name]
    @Option(name: .customLong("rc"), help: .hidden)
    public var rc: String?

    // hidden: --hard-fail
    @Flag(name: .customLong("hard-fail"), help: .hidden)
    public var hardFail: Bool = false

    public init() {}

    public mutating func run() async throws {
        // Handle -v short version flag
        if showVersion {
            print(SwiftCodeVersion.display)
            return
        }

        // Resolve output format (defaults to text)
        let format: OutputFormat
        if let rawFormat = outputFormat {
            format = OutputFormat.parse(rawFormat) ?? .text
        } else {
            format = .text
        }

        if printMode {
            // Non-interactive print mode: one prompt → response → exit
            let promptText: String
            if let p = prompt, !p.isEmpty {
                promptText = p
            } else {
                // No prompt argument → exit with usage error
                fputs("error: --print/-p requires a prompt argument\n", stderr)
                throw ExitCode(1)
            }

            let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
            let resolvedModel = model ?? "claude-opus-4-6"
            let io = StructuredIO(format: format)

            let exitCode = await PrintMode.run(
                prompt: promptText,
                outputFormat: format,
                model: resolvedModel,
                systemPrompt: systemPrompt,
                apiKey: apiKey,
                io: io
            )
            throw ExitCode(exitCode)

        } else {
            // Interactive REPL mode — resolve credentials from env or Keychain.
            // An empty key is OK: the user can run /login to set one up.
            let apiKey = await Self.resolveApiKey()
            let resolvedModel = model ?? "claude-opus-4-6"
            let client = AnthropicClient(apiKey: apiKey)
            let registry = CommandRegistry.defaultRegistry()

            let repl = InteractiveREPL(
                client: client,
                registry: registry,
                model: resolvedModel,
                systemPrompt: systemPrompt
            )

            // If a prompt is given in non-print mode, treat it as the first user message
            // and echo it in the banner area before starting the loop.
            let exitCode = await repl.run()
            throw ExitCode(exitCode)
        }
    }

    // Explicit async entry point to avoid overload ambiguity with ParsableCommand.main()
    public static func _runAsync() async {
        await Self.main()
    }

    /// Best-effort API key resolution: env var first, then Keychain.
    /// Returns an empty string if nothing is stored — the user can run /login.
    static func resolveApiKey() async -> String {
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
           !envKey.isEmpty {
            return envKey
        }
        do {
            if let stored = try CredentialStore().load() {
                switch stored {
                case .apiKey(let key): return key
                case .oauth(let token): return token.accessToken
                }
            }
        } catch {
            // Fall through; an empty key just means unauthenticated.
        }
        return ""
    }
}
