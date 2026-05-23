/// BundledSkills — registry of skills bundled with the application.
///
/// Mirrors .reference/src/skills/bundledSkills.ts and .reference/src/skills/bundled/index.ts.
///
/// Bundled skills are loaded from embedded SKILL.md resources.
/// The `verify` skill is the only one in our stub registry (per CLAUDE.md).

import Foundation

// MARK: - BundledSkillEntry

/// A single bundled skill entry with its raw SKILL.md content.
public struct BundledSkillEntry: Sendable {
    public let name: String
    public let description: String
    public let skillMDContent: String
    /// Whether the skill can be invoked by users via slash commands.
    public let userInvocable: Bool

    public init(
        name: String,
        description: String,
        skillMDContent: String,
        userInvocable: Bool = true
    ) {
        self.name = name
        self.description = description
        self.skillMDContent = skillMDContent
        self.userInvocable = userInvocable
    }

    /// Converts to a runtime `Skill` instance.
    public func toSkill() throws -> Skill {
        let (frontmatter, body) = try SkillFrontmatter.parse(skillMDContent)
        let resolvedName = frontmatter["name"] ?? name
        let resolvedDescription = frontmatter["description"] ?? description
        let pathGlobs = SkillFrontmatter.list("paths", from: frontmatter)

        return Skill(
            name: resolvedName,
            description: resolvedDescription,
            pathGlobs: pathGlobs,
            body: body,
            directory: URL(fileURLWithPath: "<bundled:\(name)>")
        )
    }
}

// MARK: - BundledSkills

/// Static registry of all bundled skills.
public enum BundledSkills {

    // MARK: - Verify skill

    /// The bundled `verify` skill.
    /// Content mirrors the placeholder SKILL.md stub (verify skill was not in the source leak).
    public static let verify = BundledSkillEntry(
        name: "verify",
        description: "Verify a code change does what it should by running the app.",
        skillMDContent: verifySkillMD,
        userInvocable: true
    )

    // MARK: - Registry

    /// All bundled skill entries.
    public static let all: [BundledSkillEntry] = [
        verify,
    ]

    /// Loads all bundled skills as runtime `Skill` instances.
    public static func load() -> [Skill] {
        all.compactMap { entry in
            try? entry.toSkill()
        }
    }

    // MARK: - Raw SKILL.md content

    private static let verifySkillMD = """
    ---
    name: verify
    description: Verify a code change does what it should by running the app.
    ---

    # Verify Skill

    Verify that a code change actually does what it's supposed to by running the app and observing behavior.

    Use when asked to verify a PR, confirm a fix works, test a change manually, check that a feature works, or validate local changes before pushing.

    ## Steps

    1. Understand what the change is supposed to do
    2. Identify how to run or invoke the affected functionality
    3. Run the app or relevant commands
    4. Observe the actual behavior
    5. Compare to expected behavior and report findings
    """
}
