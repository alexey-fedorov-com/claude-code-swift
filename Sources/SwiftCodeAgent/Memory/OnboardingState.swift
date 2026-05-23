/// OnboardingState — project onboarding state persisted to disk.
///
/// Tracks whether the user has been through the initial project setup flow.
/// Persisted to `.claude/onboarding.json` inside the project directory.
///
/// Mirrors `src/utils/onboarding.ts`.

import Foundation

// MARK: - OnboardingState

public struct OnboardingState: Codable, Equatable, Sendable {
    /// Whether the user has completed (or dismissed) the project onboarding.
    public var completed: Bool
    /// Number of times the REPL has been started for this project.
    public var sessionCount: Int
    /// First session timestamp.
    public var firstSessionAt: Date?
    /// Most recent session timestamp.
    public var lastSessionAt: Date?
    /// Whether the project CLAUDE.md has been created.
    public var hasClaudeMD: Bool
    /// User's preferred model for this project (may be nil = use global default).
    public var preferredModel: String?

    public init(
        completed: Bool = false,
        sessionCount: Int = 0,
        firstSessionAt: Date? = nil,
        lastSessionAt: Date? = nil,
        hasClaudeMD: Bool = false,
        preferredModel: String? = nil
    ) {
        self.completed = completed
        self.sessionCount = sessionCount
        self.firstSessionAt = firstSessionAt
        self.lastSessionAt = lastSessionAt
        self.hasClaudeMD = hasClaudeMD
        self.preferredModel = preferredModel
    }

    // MARK: - Persistence

    /// Load from `.claude/onboarding.json` in `projectDir`. Returns a blank state if missing.
    public static func load(from projectDir: URL) -> OnboardingState {
        let path = onboardingPath(in: projectDir)
        guard let data = try? Data(contentsOf: path) else { return OnboardingState() }
        return (try? JSONDecoder().decode(OnboardingState.self, from: data)) ?? OnboardingState()
    }

    /// Persist to `.claude/onboarding.json` in `projectDir`.
    public func save(to projectDir: URL) throws {
        let path = OnboardingState.onboardingPath(in: projectDir)
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        try data.write(to: path, options: .atomic)
    }

    private static func onboardingPath(in projectDir: URL) -> URL {
        projectDir
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("onboarding.json")
    }

    // MARK: - Mutation helpers

    /// Record a new session start and return the updated state.
    public func recordSession() -> OnboardingState {
        var s = self
        let now = Date()
        s.sessionCount += 1
        s.lastSessionAt = now
        if s.firstSessionAt == nil { s.firstSessionAt = now }
        return s
    }
}
