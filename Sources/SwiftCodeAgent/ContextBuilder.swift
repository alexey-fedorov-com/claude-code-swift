// ContextBuilder.swift
// SwiftCodeAgent
//
// Ports context assembly from:
//   .reference/src/constants/prompts.ts  → computeSimpleEnvInfo()
//   .reference/src/utils/claudemd.ts     → TODO Task 18 (CLAUDE.md loader)
//   .reference/src/utils/git.ts          → GitClient (already ported to SwiftCodeNative)
//
// ContextBuilder gathers environment variables, git state, and eventually
// CLAUDE.md contents, then produces an AgentContext which feeds the system
// prompt composer.

import Foundation
import SwiftCodeCore
import SwiftCodeNative

// MARK: - EnvironmentContext

/// Environment metadata injected into the system prompt.
/// Mirrors the fields produced by computeSimpleEnvInfo() in prompts.ts.
public struct EnvironmentContext: Sendable {
    public let workingDirectory: URL
    public let user: String
    public let hostname: String
    public let date: String
    public let platform: String
    public let shell: String
    public let osVersion: String

    public init(
        workingDirectory: URL,
        user: String,
        hostname: String,
        date: String,
        platform: String = "darwin",
        shell: String = "zsh",
        osVersion: String = "Darwin"
    ) {
        self.workingDirectory = workingDirectory
        self.user = user
        self.hostname = hostname
        self.date = date
        self.platform = platform
        self.shell = shell
        self.osVersion = osVersion
    }
}

// MARK: - GitInfo

/// Snapshot of git repository state for the current working directory.
public struct GitInfo: Sendable {
    public let isRepository: Bool
    public let branch: String?
    public let isDirty: Bool
    public let headSHA: String?
    public let worktreeCount: Int

    public init(
        isRepository: Bool,
        branch: String? = nil,
        isDirty: Bool = false,
        headSHA: String? = nil,
        worktreeCount: Int = 1
    ) {
        self.isRepository = isRepository
        self.branch = branch
        self.isDirty = isDirty
        self.headSHA = headSHA
        self.worktreeCount = worktreeCount
    }
}

// MARK: - AgentContext

/// Full runtime context available to the agent for system prompt composition.
public struct AgentContext: Sendable {
    public let environment: EnvironmentContext
    /// Contents of CLAUDE.md if found in the working directory tree.
    /// nil for now — populated by Task 18 (claudemd.ts port).
    public let claudeMDContents: String?
    /// Git info if the working directory is inside a repository.
    public let gitInfo: GitInfo?
    /// The model ID in use for this session.
    public let modelID: String?

    public init(
        environment: EnvironmentContext,
        claudeMDContents: String? = nil,
        gitInfo: GitInfo? = nil,
        modelID: String? = nil
    ) {
        self.environment = environment
        self.claudeMDContents = claudeMDContents
        self.gitInfo = gitInfo
        self.modelID = modelID
    }

    /// Renders the environment section string in the same format as
    /// computeSimpleEnvInfo() in prompts.ts.
    ///
    /// Example output:
    /// ```
    /// # Environment
    /// You have been invoked in the following environment:
    ///  - Primary working directory: /Users/alice/project
    ///  - Is a git repository: Yes
    ///  - Platform: darwin
    ///  - Shell: zsh
    ///  - OS Version: Darwin 25.0.0
    /// ```
    public func renderEnvironmentSection() -> String {
        var items: [String] = []
        items.append("Primary working directory: \(environment.workingDirectory.path)")

        if let git = gitInfo {
            items.append("Is a git repository: \(git.isRepository ? "Yes" : "No")")
            if let branch = git.branch {
                items.append("Git branch: \(branch)")
            }
        } else {
            items.append("Is a git repository: No")
        }

        items.append("Platform: \(environment.platform)")
        items.append("Shell: \(environment.shell)")
        items.append("OS Version: \(environment.osVersion)")

        if let modelID = modelID {
            items.append("Model: \(modelID)")
        }

        let bullets = items.map { " - \($0)" }.joined(separator: "\n")
        return "# Environment\nYou have been invoked in the following environment: \n\(bullets)"
    }
}

// MARK: - ContextBuilder

/// Assembles `AgentContext` from system information and git state.
///
/// Mirrors the runtime calls in `getSystemPrompt()` and `computeSimpleEnvInfo()`
/// from prompts.ts. Git state comes from SwiftCodeNative.GitClient.
///
/// CLAUDE.md loading is stubbed until Task 18.
public actor ContextBuilder {

    private let processRunner: ProcessRunner

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    /// Build an AgentContext for the given working directory.
    ///
    /// - Parameters:
    ///   - directory:  The working directory (usually CWD of the process).
    ///   - modelID:    The model ID in use (for env section).
    /// - Returns: Populated AgentContext.
    public func build(directory: URL, modelID: String? = nil) async -> AgentContext {
        let env = ProcessInfo.processInfo.environment
        let user = env["USER"] ?? env["USERNAME"] ?? "unknown"
        let hostname = ProcessInfo.processInfo.hostName
        let date = Self.formattedDate()
        let platform = Self.platformString()
        let shell = Self.shellName(env: env)
        let osVersion = Self.osVersionString()

        let environment = EnvironmentContext(
            workingDirectory: directory,
            user: user,
            hostname: hostname,
            date: date,
            platform: platform,
            shell: shell,
            osVersion: osVersion
        )

        // Git state
        let gitInfo = await buildGitInfo(directory: directory)

        // CLAUDE.md loading — TODO Task 18
        // let claudeMD = try? await ClaudeMDLoader().load(directory: directory)
        let claudeMD: String? = nil

        return AgentContext(
            environment: environment,
            claudeMDContents: claudeMD,
            gitInfo: gitInfo,
            modelID: modelID
        )
    }

    // MARK: - Private Helpers

    private func buildGitInfo(directory: URL) async -> GitInfo? {
        let gitClient = GitClient(processRunner: processRunner)
        do {
            guard let root = try await gitClient.root(in: directory) else {
                return GitInfo(isRepository: false)
            }
            async let branch = gitClient.currentBranch(in: root)
            async let dirty = gitClient.isDirty(in: root)
            async let sha = gitClient.headSHA(in: root)
            async let worktrees = gitClient.worktreeCount(in: root)
            return try await GitInfo(
                isRepository: true,
                branch: branch,
                isDirty: dirty,
                headSHA: sha,
                worktreeCount: worktrees
            )
        } catch {
            // If git fails for any reason, report non-repo
            return GitInfo(isRepository: false)
        }
    }

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    private static func platformString() -> String {
        #if os(macOS)
        return "darwin"
        #elseif os(Linux)
        return "linux"
        #elseif os(Windows)
        return "win32"
        #else
        return "unknown"
        #endif
    }

    private static func shellName(env: [String: String]) -> String {
        let shell = env["SHELL"] ?? "unknown"
        if shell.contains("zsh") { return "zsh" }
        if shell.contains("bash") { return "bash" }
        if shell.contains("fish") { return "fish" }
        return shell
    }

    private static func osVersionString() -> String {
        let ver = ProcessInfo.processInfo.operatingSystemVersionString
        return ver
    }
}
