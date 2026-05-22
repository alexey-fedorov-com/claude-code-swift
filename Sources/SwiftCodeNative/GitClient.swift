/// Git repository inspection using subprocess calls.
///
/// Mirrors the TypeScript reference at:
/// - src/utils/git.ts   (findGitRoot, getIsClean, getBranch, getWorktreeCount)
/// - src/utils/git/gitFilesystem.ts (getWorktreeCountFromFs)
///
/// All operations are async and use `ProcessRunner` to invoke `git`.

import Foundation

// MARK: - GitClient

public struct GitClient: Sendable {

    private let processRunner: ProcessRunner

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    // MARK: Root discovery

    /// Walks up the directory tree looking for a `.git` entry (file or directory).
    ///
    /// Mirrors `findGitRootImpl` in `git.ts`.
    ///
    /// - Returns: The directory that contains `.git`, or `nil` if not inside a repo.
    public func root(in directory: URL) async throws -> URL? {
        var current = directory.standardized
        let fileManager = FileManager.default

        while true {
            let gitPath = current.appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: gitPath.path, isDirectory: &isDir) {
                // .git can be a file (worktree/submodule) or directory (normal repo)
                return current
            }
            let parent = current.deletingLastPathComponent()
            // Reached the filesystem root
            if parent.path == current.path {
                break
            }
            current = parent
        }
        return nil
    }

    // MARK: Branch

    /// Returns the current branch name, or `nil` if in detached HEAD state.
    ///
    /// Runs: `git rev-parse --abbrev-ref HEAD`
    public func currentBranch(in directory: URL) async throws -> String? {
        let result = try await processRunner.run(
            executable: "git",
            arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            workingDirectory: directory
        )
        guard result.exitCode == 0 else { return nil }
        let branch = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        // Detached HEAD → git prints "HEAD"
        return branch == "HEAD" ? nil : branch
    }

    // MARK: Dirty state

    /// Returns `true` if the working tree has any staged or unstaged changes.
    ///
    /// Runs: `git --no-optional-locks status --porcelain`
    /// Mirrors `getIsClean` in `git.ts`.
    public func isDirty(in directory: URL) async throws -> Bool {
        let result = try await processRunner.run(
            executable: "git",
            arguments: ["--no-optional-locks", "status", "--porcelain"],
            workingDirectory: directory
        )
        guard result.exitCode == 0 else { return false }
        return !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Returns `true` if the working tree has untracked files.
    ///
    /// Parses porcelain output looking for lines that start with `??`.
    public func hasUntrackedFiles(in directory: URL) async throws -> Bool {
        let result = try await processRunner.run(
            executable: "git",
            arguments: ["--no-optional-locks", "status", "--porcelain"],
            workingDirectory: directory
        )
        guard result.exitCode == 0 else { return false }
        return result.stdout.components(separatedBy: "\n").contains { line in
            line.hasPrefix("??")
        }
    }

    // MARK: Worktree count

    /// Returns the total number of worktrees (including the main one).
    ///
    /// Runs: `git worktree list --porcelain`
    /// Each worktree entry starts with a `worktree` line; count those.
    /// Mirrors `getWorktreeCountFromFs` in `git.ts`.
    public func worktreeCount(in directory: URL) async throws -> Int {
        let result = try await processRunner.run(
            executable: "git",
            arguments: ["worktree", "list", "--porcelain"],
            workingDirectory: directory
        )
        guard result.exitCode == 0 else { return 1 }
        let count = result.stdout
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("worktree ") }
            .count
        return max(count, 1)
    }

    // MARK: HEAD SHA

    /// Returns the full SHA of HEAD, or `nil` if not in a repo / no commits.
    public func headSHA(in directory: URL) async throws -> String? {
        let result = try await processRunner.run(
            executable: "git",
            arguments: ["rev-parse", "HEAD"],
            workingDirectory: directory
        )
        guard result.exitCode == 0 else { return nil }
        let sha = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return sha.isEmpty ? nil : sha
    }

    // MARK: Remote URL

    /// Returns the `origin` remote URL, or `nil` if none is configured.
    public func originURL(in directory: URL) async throws -> String? {
        let result = try await processRunner.run(
            executable: "git",
            arguments: ["remote", "get-url", "origin"],
            workingDirectory: directory
        )
        guard result.exitCode == 0 else { return nil }
        let url = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }
}
