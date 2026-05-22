/// GrepTool — search file contents using ripgrep (rg) or NSRegularExpression fallback.
///
/// Reference: .reference/src/tools/GrepTool/GrepTool.ts
///
/// output_mode:
///   "content"            — show matching lines with file:line:content format (default)
///   "files_with_matches" — show only file paths with at least one match

import Foundation
import SwiftCodeCore
import SwiftCodeNative

// MARK: - GrepTool

public struct GrepTool: ToolHandler {
    public let name = "Grep"
    public let description = """
        Fast content search tool that works with any codebase size. Searches file \
        contents for the given pattern. Prefer ripgrep (rg) when available.
        """

    public let inputSchema = ToolInputSchema(
        properties: [
            "pattern": PropertySchema(
                type: "string",
                description: "The regular expression pattern to search for."
            ),
            "path": PropertySchema(
                type: "string",
                description: "The directory or file to search. Defaults to current directory."
            ),
            "output_mode": PropertySchema(
                type: "string",
                description: "Output mode: 'content' (default) or 'files_with_matches'.",
                enum: ["content", "files_with_matches"]
            ),
            "glob": PropertySchema(
                type: "string",
                description: "Glob pattern to restrict which files are searched (e.g. **/*.swift)."
            ),
            "-i": PropertySchema(
                type: "boolean",
                description: "Case-insensitive matching."
            ),
            "-n": PropertySchema(
                type: "boolean",
                description: "Show line numbers (default true for content mode)."
            )
        ],
        required: ["pattern"]
    )

    private let runner: ProcessRunner

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    public func execute(input: [String: JSONValue]) async throws -> String {
        guard let pattern = input["pattern"]?.stringValue else {
            throw ToolError.invalidInput(tool: name, message: "pattern is required")
        }

        let searchPath: String
        if let p = input["path"]?.stringValue, !p.isEmpty {
            searchPath = p
        } else {
            searchPath = FileManager.default.currentDirectoryPath
        }

        let outputMode = input["output_mode"]?.stringValue ?? "content"
        let globPattern = input["glob"]?.stringValue
        let caseInsensitive = input["-i"]?.boolValue ?? false

        // Try rg first, fall back to NSRegularExpression
        if let rgPath = findExecutable("rg") {
            return try await runRipgrep(
                rgPath: rgPath,
                pattern: pattern,
                searchPath: searchPath,
                outputMode: outputMode,
                glob: globPattern,
                caseInsensitive: caseInsensitive
            )
        } else {
            return try await runNSRegex(
                pattern: pattern,
                searchPath: searchPath,
                outputMode: outputMode,
                glob: globPattern,
                caseInsensitive: caseInsensitive
            )
        }
    }

    // MARK: - rg path

    private func runRipgrep(
        rgPath: String,
        pattern: String,
        searchPath: String,
        outputMode: String,
        glob: String?,
        caseInsensitive: Bool
    ) async throws -> String {
        var args: [String] = []

        if caseInsensitive { args.append("-i") }
        if outputMode == "files_with_matches" {
            args.append("-l")
        } else {
            args.append("--line-number")
            args.append("--with-filename")
        }

        if let g = glob {
            args.append(contentsOf: ["--glob", g])
        }

        args.append("--")
        args.append(pattern)
        args.append(searchPath)

        let result = try await runner.run(executable: rgPath, arguments: args, timeout: 30)

        if result.exitCode == 1 && result.stdout.isEmpty {
            return "No matches found"
        }
        return result.stdout.isEmpty ? result.stderr : result.stdout
    }

    // MARK: - NSRegularExpression fallback

    private func runNSRegex(
        pattern: String,
        searchPath: String,
        outputMode: String,
        glob: String?,
        caseInsensitive: Bool
    ) async throws -> String {
        var options: NSRegularExpression.Options = []
        if caseInsensitive { options.insert(.caseInsensitive) }

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            throw ToolError.invalidInput(tool: name, message: "invalid regex: \(error.localizedDescription)")
        }

        let globRegex: NSRegularExpression? = glob.flatMap { try? globToRegex($0) }

        return try await Task.detached(priority: .userInitiated) {
            try self.walkAndGrep(
                root: URL(fileURLWithPath: searchPath).resolvingSymlinksInPath(),
                regex: regex,
                globRegex: globRegex,
                outputMode: outputMode
            )
        }.value
    }

    private func walkAndGrep(
        root: URL,
        regex: NSRegularExpression,
        globRegex: NSRegularExpression?,
        outputMode: String
    ) throws -> String {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        fm.fileExists(atPath: root.path, isDirectory: &isDir)

        let urls: [URL]
        if isDir.boolValue {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return "No matches found" }
            urls = (enumerator.allObjects as? [URL] ?? []).filter {
                (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }
        } else {
            urls = [root]
        }

        var lines: [String] = []
        var matchedFiles: [String] = []

        for url in urls {
            // Apply glob filter if any
            if let globRegex {
                let relative = url.path.hasPrefix(root.path)
                    ? String(url.path.dropFirst(root.path.count + 1))
                    : url.path
                let range = NSRange(relative.startIndex..., in: relative)
                guard globRegex.firstMatch(in: relative, range: range) != nil else { continue }
            }

            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }

            let contentLines = contents.components(separatedBy: "\n")
            var fileMatched = false

            for (idx, line) in contentLines.enumerated() {
                let lineRange = NSRange(line.startIndex..., in: line)
                guard regex.firstMatch(in: line, range: lineRange) != nil else { continue }

                fileMatched = true
                if outputMode == "content" {
                    lines.append("\(url.path):\(idx + 1):\(line)")
                }
            }

            if fileMatched && outputMode == "files_with_matches" {
                matchedFiles.append(url.path)
            }
        }

        if outputMode == "files_with_matches" {
            return matchedFiles.isEmpty ? "No matches found" : matchedFiles.sorted().joined(separator: "\n")
        }
        return lines.isEmpty ? "No matches found" : lines.joined(separator: "\n")
    }
}

// MARK: - Helpers

private func findExecutable(_ name: String) -> String? {
    let paths = ProcessInfo.processInfo.environment["PATH"]?
        .components(separatedBy: ":") ?? []
    for dir in paths {
        let full = (dir as NSString).appendingPathComponent(name)
        if FileManager.default.isExecutableFile(atPath: full) {
            return full
        }
    }
    return nil
}

private func globToRegex(_ glob: String) throws -> NSRegularExpression {
    var pattern = "^"
    var i = glob.startIndex
    while i < glob.endIndex {
        let c = glob[i]
        if c == "*" {
            let next = glob.index(after: i)
            if next < glob.endIndex && glob[next] == "*" {
                pattern += ".*"
                i = glob.index(after: next)
                if i < glob.endIndex && glob[i] == "/" { i = glob.index(after: i) }
            } else {
                pattern += "[^/]*"
                i = next
            }
        } else if c == "?" {
            pattern += "[^/]"
            i = glob.index(after: i)
        } else {
            pattern += NSRegularExpression.escapedPattern(for: String(c))
            i = glob.index(after: i)
        }
    }
    pattern += "$"
    return try NSRegularExpression(pattern: pattern)
}
