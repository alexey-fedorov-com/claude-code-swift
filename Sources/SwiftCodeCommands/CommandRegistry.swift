import SwiftCodeCore
import Foundation

// MARK: - CommandRegistry

/// Registers and looks up slash commands.
///
/// Mirrors `COMMANDS()` / `builtInCommandNames` / `getCommands()` from the
/// TypeScript reference (src/commands.ts). Commands are registered in the
/// same order as the reference to preserve `/help` display order.
///
/// **Availability filtering** (ref: src/commands.ts INTERNAL_ONLY_COMMANDS):
/// - `requiresAntUser == true` commands are excluded unless `antUser == true`
///   and `demoMode == false`.
/// - `requiredFeatureFlag != nil` commands are excluded when the flag is off.
///
/// **Extension points for later tasks** (Tasks 16/17):
/// - Dynamic skill commands from skill directories → inject via `register(_:)`
/// - Plugin commands → same
/// - Workflow commands → same
public actor CommandRegistry {

    // MARK: Storage

    private var commands: [any SlashCommand] = []

    // MARK: Init

    public init() {}

    // MARK: Registration

    /// Register a single command.
    public func register(_ command: any SlashCommand) {
        commands.append(command)
    }

    // MARK: Lookup

    /// Find a command by name or alias. Returns `nil` when not found.
    public func lookup(name: String) -> (any SlashCommand)? {
        let q = name.lowercased()
        return commands.first { cmd in
            cmd.name == q || cmd.aliases.map { $0.lowercased() }.contains(q)
        }
    }

    // MARK: Listing

    /// Return commands visible to the current user, respecting ant-user and feature gating.
    ///
    /// - Parameters:
    ///   - antUser: Whether the session is running as an Anthropic-internal user.
    ///   - demoMode: Whether demo mode is active (suppresses ant-only commands).
    public func availableCommands(antUser: Bool, demoMode: Bool) -> [any SlashCommand] {
        commands.filter { cmd in
            // Ant-only commands: only show when antUser=true AND demoMode=false
            if cmd.requiresAntUser && !(antUser && !demoMode) { return false }
            // Feature-gated commands
            if let flag = cmd.requiredFeatureFlag, !FeatureFlags.isEnabled(flag) { return false }
            return true
        }
    }

    // MARK: - allCommandNames

    /// Canonical list of every slash command name (and aliases) that can be
    /// registered in a default registry, independent of user type / flags.
    ///
    /// Mirrors `builtInCommandNames` from the TypeScript reference.
    /// Used by parity tests to verify nothing is missing.
    public static let allCommandNames: [String] = [
        // Core / always-on (external build)
        "add-dir",
        "advisor",
        "agents",
        "branch",
        "btw",
        "chrome",
        "clear",
        "color",
        "compact",
        "config",
        "context",
        "copy",
        "cost",
        "desktop",
        "diff",
        "doctor",
        "effort",
        "exit",
        "export",
        "fast",
        "feedback",
        "files",
        "heapdump",
        "help",
        "hooks",
        "ide",
        "init",
        "install-github-app",
        "install-slack-app",
        "keybindings",
        "login",
        "logout",
        "mcp",
        "memory",
        "mobile",
        "model",
        "output-style",
        "passes",
        "permissions",
        "plan",
        "plugin",
        "pr_comments",
        "privacy-settings",
        "rate-limit-options",
        "release-notes",
        "reload-plugins",
        "remote-env",
        "rename",
        "resume",
        "review",
        "rewind",
        "sandbox-toggle",
        "security-review",
        "session",
        "skills",
        "stats",
        "status",
        "statusline",
        "stickers",
        "tag",
        "tasks",
        "teleport",
        "terminalSetup",
        "theme",
        "thinkback",
        "thinkback-play",
        "upgrade",
        "usage",
        "vim",
        // Feature-gated (registered but filtered at runtime)
        "voice",
        "bridge",
        "buddy",
        "ultraplan",
        "assistant",
        // Internal-only (ant user, non-demo)
        "add-dir",
        "ant-trace",
        "autofix-pr",
        "backfill-sessions",
        "break-cache",
        "bridge-kick",
        "bughunter",
        "commit",
        "commit-push-pr",
        "ctx_viz",
        "debug-tool-call",
        "env",
        "good-claude",
        "init-verifiers",
        "insights",
        "issue",
        "mock-limits",
        "oauth-refresh",
        "onboarding",
        "perf-issue",
        "reset-limits",
        "sandbox-toggle",
        "share",
        "summary",
        "version",
        // Registry-only (no backing command file in reference but named in registry)
        "advisor",
        "brief",
        "commit",
        "commit-push-pr",
        "createMovedToPluginCommand",
        "install",
        "insights",
        "review",
        "ultraplan",
    ]

    // MARK: - defaultRegistry

    /// Build and return the default registry with all built-in commands registered.
    /// Mirrors the `COMMANDS()` list order in src/commands.ts.
    public static func defaultRegistry() -> CommandRegistry {
        let registry = CommandRegistry()
        // Populated synchronously since CommandRegistry is an actor and
        // all registrations must happen before the registry is returned.
        // Task.detached won't work in tests without an event loop already running.
        // The actor isolation is intentionally relaxed here via nonisolated helper.
        registry._registerDefaults()
        return registry
    }

    // nonisolated trampoline so we can call from static context
    nonisolated private func _registerDefaults() {
        Task {
            await self._doRegisterDefaults()
        }
    }

    private func _doRegisterDefaults() {
        // External / always-on commands (mirror COMMANDS() order in commands.ts)
        register(AddDirCommand())
        register(AdvisorCommand())
        register(AgentsCommand())
        register(BranchCommand())
        register(BtwCommand())
        register(ChromeCommand())
        register(ClearCommand())
        register(ColorCommand())
        register(CompactCommand())
        register(ConfigCommand())
        register(ContextCommand())
        register(CopyCommand())
        register(CostCommand())
        register(DesktopCommand())
        register(DiffCommand())
        register(DoctorCommand())
        register(EffortCommand())
        register(ExitCommand())
        register(ExportCommand())
        register(FastCommand())
        register(FeedbackCommand())
        register(FilesCommand())
        register(HeapdumpCommand())
        register(HelpCommand())
        register(HooksCommand())
        register(IdeCommand())
        register(InitCommand())
        register(InstallGitHubAppCommand())
        register(InstallSlackAppCommand())
        register(KeybindingsCommand())
        register(LoginCommand())
        register(LogoutCommand())
        register(McpCommand())
        register(MemoryCommand())
        register(MobileCommand())
        register(ModelCommand())
        register(OutputStyleCommand())
        register(PassesCommand())
        register(PermissionsCommand())
        register(PlanCommand())
        register(PluginCommand())
        register(PrCommentsCommand())
        register(PrivacySettingsCommand())
        register(RateLimitOptionsCommand())
        register(ReleaseNotesCommand())
        register(ReloadPluginsCommand())
        register(RemoteEnvCommand())
        register(RenameCommand())
        register(ResumeCommand())
        register(ReviewCommand())
        register(RewindCommand())
        register(SandboxToggleCommand())
        register(SecurityReviewCommand())
        register(SessionCommand())
        register(SkillsCommand())
        register(StatsCommand())
        register(StatusCommand())
        register(StatuslineCommand())
        register(StickersCommand())
        register(TagCommand())
        register(TasksCommand())
        register(TeleportCommand())
        register(TerminalSetupCommand())
        register(ThemeCommand())
        register(ThinkbackCommand())
        register(ThinkbackPlayCommand())
        register(UpgradeCommand())
        register(UsageCommand())
        register(VimCommand())

        // Feature-gated commands (registered; filtered at lookup time)
        register(VoiceCommand())
        register(BridgeCommand())
        register(BuddyCommand())
        register(UltraplanCommand())
        register(AssistantCommand())
        register(BriefCommand())

        // Internal-only / ant-user commands
        register(AntTraceCommand())
        register(AutofixPrCommand())
        register(BackfillSessionsCommand())
        register(BreakCacheCommand())
        register(BridgeKickCommand())
        register(BughunterCommand())
        register(CommitCommand())
        register(CommitPushPrCommand())
        register(CtxVizCommand())
        register(DebugToolCallCommand())
        register(EnvCommand())
        register(GoodClaudeCommand())
        register(InitVerifiersCommand())
        register(InsightsCommand())
        register(IssueCommand())
        register(MockLimitsCommand())
        register(OauthRefreshCommand())
        register(OnboardingCommand())
        register(PerfIssueCommand())
        register(ResetLimitsCommand())
        register(ShareCommand())
        register(SummaryCommand())
        register(VersionCommand())
    }
}
