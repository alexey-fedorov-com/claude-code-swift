/// HookOutput — handles large hook output (>50K bytes).
///
/// 2.1.89 backport: "Hook output >50K saved to disk — large hook output written
/// to temp file with path + preview instead of injecting into context."
///
/// Mirrors the behaviour from .reference/src/utils/hooks/hooks.ts.

import Foundation

// MARK: - HookOutput

public enum HookOutput {
    /// Maximum number of bytes to keep inline.
    /// Output beyond this threshold is written to a temp file.
    public static let maxInlineBytes = 50_000

    /// Inline preview length when output is truncated to disk.
    public static let previewLength = 200

    /// Processes hook command output.
    ///
    /// - If `output` is ≤ `maxInlineBytes`, returns it inline with `path == nil`.
    /// - If `output` exceeds `maxInlineBytes`, writes the full content to a temp
    ///   file and returns a short preview + the file URL.
    ///
    /// - Parameters:
    ///   - output: Raw stdout+stderr string from the hook process.
    ///   - sessionId: Used to name the temp file for traceability.
    /// - Returns: `(preview, path)` — `path` is nil when output fits inline.
    public static func process(
        _ output: String,
        sessionId: String
    ) throws -> (preview: String, path: URL?) {
        let bytes = output.utf8.count

        if bytes <= maxInlineBytes {
            return (output, nil)
        }

        // Write full output to a temp file
        let tmpDir = FileManager.default.temporaryDirectory
        let filename = "claude-hook-\(sessionId)-\(UUID().uuidString.prefix(8)).txt"
        let fileURL = tmpDir.appendingPathComponent(filename)

        try output.write(to: fileURL, atomically: true, encoding: .utf8)

        // Return a short preview
        let previewEnd = output.index(output.startIndex, offsetBy: min(previewLength, output.count))
        let preview = String(output[output.startIndex..<previewEnd])

        return (preview, fileURL)
    }

    /// Formats the inline message that replaces raw output when content is saved to disk.
    ///
    /// Example: "[Hook output truncated — full output at /tmp/claude-hook-abc123.txt]\n...preview..."
    public static func truncationMessage(preview: String, path: URL) -> String {
        "[Hook output truncated — full output at \(path.path)]\n\(preview)…"
    }
}
