/// HookOutputTruncationTests — tests for the 50K output truncation behaviour.
///
/// 2.1.89 backport: Hook output >50K saved to disk.

import Testing
import Foundation
@testable import SwiftCodeHooks

@Suite("HookOutput Truncation")
struct HookOutputTruncationTests {

    @Test("small output stays inline (no file written)")
    func smallOutputInline() throws {
        let output = "hello, this is hook output"
        let (preview, path) = try HookOutput.process(output, sessionId: "test-session")
        #expect(preview == output)
        #expect(path == nil)
    }

    @Test("exactly at limit stays inline")
    func atLimitInline() throws {
        let output = String(repeating: "x", count: HookOutput.maxInlineBytes)
        let (_, path) = try HookOutput.process(output, sessionId: "at-limit")
        #expect(path == nil)
    }

    @Test("2.1.89: output over 50K is written to disk")
    func largeOutputWrittenToDisk() throws {
        let output = String(repeating: "a", count: HookOutput.maxInlineBytes + 1)
        let (preview, path) = try HookOutput.process(output, sessionId: "large-output")

        // Path must be set
        #expect(path != nil)

        // File must exist with full content
        if let fileURL = path {
            let written = try String(contentsOf: fileURL, encoding: .utf8)
            #expect(written == output)

            // Clean up
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Preview must be short
        #expect(preview.count <= HookOutput.previewLength + 10)
    }

    @Test("2.1.89: preview is a prefix of the full output")
    func previewIsPrefix() throws {
        let output = String(repeating: "b", count: HookOutput.maxInlineBytes + 500)
        let (preview, path) = try HookOutput.process(output, sessionId: "prefix-test")

        #expect(output.hasPrefix(preview))
        if let fileURL = path {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    @Test("truncationMessage contains path and preview")
    func truncationMessageFormat() {
        let path = URL(fileURLWithPath: "/tmp/claude-hook-test.txt")
        let preview = "first line..."
        let msg = HookOutput.truncationMessage(preview: preview, path: path)
        #expect(msg.contains(path.path))
        #expect(msg.contains(preview))
    }

    @Test("different sessions produce different filenames")
    func uniqueFilenames() throws {
        let output = String(repeating: "c", count: HookOutput.maxInlineBytes + 1)
        let (_, path1) = try HookOutput.process(output, sessionId: "sess-1")
        let (_, path2) = try HookOutput.process(output, sessionId: "sess-2")

        #expect(path1 != path2)

        [path1, path2].compactMap { $0 }.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test("maxInlineBytes is 50000")
    func maxInlineBytesValue() {
        #expect(HookOutput.maxInlineBytes == 50_000)
    }
}
