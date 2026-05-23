/// SkillLoader — loads SKILL.md files from disk.
///
/// Mirrors .reference/src/skills/loadSkillsDir.ts and related files.
///
/// Skills are discovered from:
/// 1. `~/.claude/skills/` (user skills)
/// 2. `.claude/skills/` in each project directory (project skills)
/// 3. Bundled skills embedded in the app

import Foundation
import SwiftCodeCore

// MARK: - Skill

/// A discovered and parsed skill.
public struct Skill: Sendable, Equatable {
    /// Skill name (derived from `name:` frontmatter or filename without extension).
    public let name: String
    /// Human-readable description (from `description:` frontmatter).
    public let description: String
    /// Glob patterns for path-triggered activation (from `paths:` frontmatter).
    public let pathGlobs: [String]
    /// The skill body text (Markdown after frontmatter is stripped).
    public let body: String
    /// Directory containing the SKILL.md file.
    public let directory: URL

    public init(
        name: String,
        description: String = "",
        pathGlobs: [String] = [],
        body: String,
        directory: URL
    ) {
        self.name = name
        self.description = description
        self.pathGlobs = pathGlobs
        self.body = body
        self.directory = directory
    }

    // MARK: - Equatable

    public static func == (lhs: Skill, rhs: Skill) -> Bool {
        lhs.name == rhs.name && lhs.directory == rhs.directory
    }

    // MARK: - Path matching

    /// Returns true if this skill should be activated for the given path.
    public func matches(path: String) -> Bool {
        guard !pathGlobs.isEmpty else { return false }
        return pathGlobs.contains { globPattern in
            fnmatch(globPattern, path, FNM_PATHNAME) == 0
        }
    }
}

// MARK: - SkillLoadError

public enum SkillLoadError: Error, LocalizedError {
    case invalidFile(URL)
    case parseError(URL, Error)

    public var errorDescription: String? {
        switch self {
        case .invalidFile(let url):
            return "Invalid skill file: \(url.path)"
        case .parseError(let url, let error):
            return "Failed to parse skill at \(url.path): \(error.localizedDescription)"
        }
    }
}

// MARK: - SkillLoader

/// Actor that discovers and loads SKILL.md files from configured search paths.
public actor SkillLoader {
    private let searchPaths: [URL]

    /// - Parameter searchPaths: Directories to search for skills.
    ///   Defaults to `~/.claude/skills/`.
    public init(searchPaths: [URL] = [SkillLoader.defaultSkillsDirectory()]) {
        self.searchPaths = searchPaths
    }

    /// Returns the default user skills directory: `~/.claude/skills/`
    public static func defaultSkillsDirectory() -> URL {
        ConfigPaths.configHomeDirectory()
            .appendingPathComponent("skills", isDirectory: true)
    }

    // MARK: - Discovery

    /// Discovers all skills from all search paths.
    ///
    /// Each search path is scanned for:
    /// - `SKILL.md` files in immediate subdirectories
    /// - Standalone `*.md` files at the search path root
    public func discover() async throws -> [Skill] {
        var skills: [Skill] = []
        let fm = FileManager.default

        for searchPath in searchPaths {
            guard fm.fileExists(atPath: searchPath.path) else { continue }

            let entries = try fm.contentsOfDirectory(
                at: searchPath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for entry in entries {
                var isDir: ObjCBool = false
                fm.fileExists(atPath: entry.path, isDirectory: &isDir)

                if isDir.boolValue {
                    // Look for SKILL.md inside the directory
                    let skillMD = entry.appendingPathComponent("SKILL.md")
                    if fm.fileExists(atPath: skillMD.path),
                       let skill = try? loadSkill(from: skillMD, in: entry) {
                        skills.append(skill)
                    }
                } else if entry.pathExtension.lowercased() == "md" {
                    // Standalone .md file
                    if let skill = try? loadSkill(from: entry, in: entry.deletingLastPathComponent()) {
                        skills.append(skill)
                    }
                }
            }
        }

        return skills.sorted { $0.name < $1.name }
    }

    /// Loads a single skill from a SKILL.md file.
    public func loadSkill(from fileURL: URL, in directory: URL) throws -> Skill {
        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw SkillLoadError.parseError(fileURL, error)
        }

        let (frontmatter, body): ([String: String], String)
        do {
            (frontmatter, body) = try SkillFrontmatter.parse(content)
        } catch {
            throw SkillLoadError.parseError(fileURL, error)
        }

        // Derive name: frontmatter > directory name > filename stem
        let name = frontmatter["name"]
            ?? directory.lastPathComponent
            .replacingOccurrences(of: ".md", with: "")

        let description = frontmatter["description"] ?? ""
        let pathGlobs = SkillFrontmatter.list("paths", from: frontmatter)

        return Skill(
            name: name,
            description: description,
            pathGlobs: pathGlobs,
            body: body,
            directory: directory
        )
    }
}
