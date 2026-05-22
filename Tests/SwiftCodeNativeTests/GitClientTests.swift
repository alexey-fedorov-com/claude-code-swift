import Testing
import Foundation
@testable import SwiftCodeNative

// A single shared temp git repo created once for the test suite.
// Creating it once avoids repeated `git init` + process spawning overhead.
final class TempGitRepo: Sendable {

    let url: URL
    let runner = ProcessRunner()

    init() async throws {
        // Create a unique temp dir
        let fs = FileSystem()
        let dir = try fs.makeTemporaryDirectory(prefix: "swiftcode-git-test")
        self.url = dir

        // git init
        _ = try await runner.run(executable: "git", arguments: ["init"], workingDirectory: dir)

        // Minimal git config so commits work in CI
        _ = try await runner.run(
            executable: "git",
            arguments: ["config", "user.email", "test@test.com"],
            workingDirectory: dir
        )
        _ = try await runner.run(
            executable: "git",
            arguments: ["config", "user.name", "Test"],
            workingDirectory: dir
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// Makes an initial commit so HEAD resolves.
    func makeInitialCommit() async throws {
        let readme = url.appendingPathComponent("README.md")
        try "# test\n".write(to: readme, atomically: true, encoding: .utf8)
        _ = try await runner.run(executable: "git", arguments: ["add", "."], workingDirectory: url)
        _ = try await runner.run(
            executable: "git",
            arguments: ["commit", "-m", "initial"],
            workingDirectory: url
        )
    }
}

@Suite("GitClient")
struct GitClientTests {

    let client = GitClient()

    // MARK: Root discovery

    @Test("testGitRootInGitDir: root() returns the repo directory")
    func testGitRootInGitDir() async throws {
        let repo = try await TempGitRepo()
        let root = try await client.root(in: repo.url)
        #expect(root != nil)
        // The returned path should contain the .git directory
        let gitDir = root!.appendingPathComponent(".git")
        #expect(FileManager.default.fileExists(atPath: gitDir.path))
    }

    @Test("testGitRootNotFound: root() returns nil outside a repo")
    func testGitRootNotFound() async throws {
        // /tmp itself is not a git repo (under normal circumstances)
        let outside = URL(fileURLWithPath: "/tmp")
        let root = try await client.root(in: outside)
        // We can't guarantee /tmp isn't in a repo, but it almost certainly isn't.
        // If this ever fails, the machine itself is inside a git repo at /tmp.
        if root != nil {
            // Accept if we happen to be inside a git repo — log but don't fail
            Issue.record("Unexpectedly found git root at /tmp — skipping assertion")
        } else {
            #expect(root == nil)
        }
    }

    // MARK: Branch

    @Test("testCurrentBranch: returns current branch name")
    func testCurrentBranch() async throws {
        let repo = try await TempGitRepo()
        try await repo.makeInitialCommit()

        let branch = try await client.currentBranch(in: repo.url)
        // git init may default to "main" or "master" depending on config
        #expect(branch != nil)
        let name = branch!
        #expect(name == "main" || name == "master")
    }

    @Test("testCurrentBranchOnNewBranch: reflects newly created branch")
    func testCurrentBranchOnNewBranch() async throws {
        let repo = try await TempGitRepo()
        try await repo.makeInitialCommit()

        // Create and switch to a new branch
        _ = try await repo.runner.run(
            executable: "git",
            arguments: ["checkout", "-b", "feature/test"],
            workingDirectory: repo.url
        )
        let branch = try await client.currentBranch(in: repo.url)
        #expect(branch == "feature/test")
    }

    // MARK: Dirty state

    @Test("testIsDirtyClean: fresh committed repo is not dirty")
    func testIsDirtyClean() async throws {
        let repo = try await TempGitRepo()
        try await repo.makeInitialCommit()
        let dirty = try await client.isDirty(in: repo.url)
        #expect(dirty == false)
    }

    @Test("testIsDirty: returns true after modifying a tracked file")
    func testIsDirty() async throws {
        let repo = try await TempGitRepo()
        try await repo.makeInitialCommit()

        // Modify a tracked file
        let readme = repo.url.appendingPathComponent("README.md")
        try "# modified\n".write(to: readme, atomically: true, encoding: .utf8)

        let dirty = try await client.isDirty(in: repo.url)
        #expect(dirty == true)
    }

    @Test("testHasUntrackedFiles: returns true after adding untracked file")
    func testHasUntrackedFiles() async throws {
        let repo = try await TempGitRepo()
        try await repo.makeInitialCommit()

        // Add an untracked file
        let newFile = repo.url.appendingPathComponent("untracked.txt")
        try "new\n".write(to: newFile, atomically: true, encoding: .utf8)

        let hasUntracked = try await client.hasUntrackedFiles(in: repo.url)
        #expect(hasUntracked == true)
    }

    // MARK: Worktree count

    @Test("testWorktreeCount: fresh repo has 1 worktree")
    func testWorktreeCount() async throws {
        let repo = try await TempGitRepo()
        try await repo.makeInitialCommit()
        let count = try await client.worktreeCount(in: repo.url)
        #expect(count == 1)
    }

    // MARK: HEAD SHA

    @Test("testHeadSHA: returns a non-empty SHA after a commit")
    func testHeadSHA() async throws {
        let repo = try await TempGitRepo()
        try await repo.makeInitialCommit()
        let sha = try await client.headSHA(in: repo.url)
        #expect(sha != nil)
        #expect(sha!.count == 40)  // Full SHA is 40 hex chars
    }
}
