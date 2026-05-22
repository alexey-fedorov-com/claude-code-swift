// SystemPromptParityTests.swift
// SwiftCodeAgentTests
//
// Verifies that the ported system prompt contains the expected content
// from .reference/src/constants/prompts.ts.

import Testing
import Foundation
@testable import SwiftCodeAgent
import SwiftCodeCore

@Suite("System Prompt Parity")
struct SystemPromptParityTests {

    // MARK: - Core Text Content

    @Test("Core system prompt includes product name")
    func testCoreSystemPromptIncludesProductName() {
        let text = SystemPrompt.coreText
        // The ported text should reference "Swift Code" (our product name)
        #expect(text.contains("Swift Code"), "System prompt should mention Swift Code")
    }

    @Test("Core system prompt includes version reference")
    func testCoreSystemPromptIncludesCurrentVersion() {
        let version = SystemPrompt.version
        #expect(version == "2.1.88", "Version should match MACRO.VERSION from build.ts")
    }

    @Test("Core system prompt line count is substantial")
    func testCoreSystemPromptLineCount() {
        let lineCount = SystemPrompt.coreText.components(separatedBy: "\n").count
        // We ported the major static sections (intro, system, doing tasks,
        // actions, tool guidance, tone, output efficiency). Expect at least 65 lines.
        #expect(lineCount >= 65, "Core prompt should have at least 65 lines, got \(lineCount)")
    }

    @Test("Core system prompt includes safety / security guidance")
    func testCoreSystemPromptIncludesSecurityGuidance() {
        let text = SystemPrompt.coreText
        #expect(text.contains("security vulnerabilities") || text.contains("SQL injection"),
                "Prompt should include security guidance")
    }

    @Test("Core system prompt includes action reversibility guidance")
    func testCoreSystemPromptIncludesActionGuidance() {
        let text = SystemPrompt.coreText
        #expect(text.contains("reversibility") || text.contains("blast radius"),
                "Prompt should include 'Executing actions with care' section")
    }

    @Test("Core system prompt includes tool usage guidance")
    func testCoreSystemPromptIncludesToolGuidance() {
        let text = SystemPrompt.coreText
        #expect(text.contains("dedicated tool") || text.contains("parallel"),
                "Prompt should include tool usage guidance")
    }

    @Test("Core system prompt includes tone and style section")
    func testCoreSystemPromptIncludesToneSection() {
        let text = SystemPrompt.coreText
        #expect(text.contains("Tone and style") || text.contains("emojis"),
                "Prompt should include tone/style guidance")
    }

    @Test("Core system prompt includes output efficiency section")
    func testCoreSystemPromptIncludesOutputEfficiency() {
        let text = SystemPrompt.coreText
        #expect(text.contains("Output efficiency") || text.contains("concise"),
                "Prompt should include output efficiency guidance")
    }

    @Test("Dynamic boundary constant is correct")
    func testDynamicBoundaryConstant() {
        #expect(SystemPrompt.dynamicBoundary == "__SYSTEM_PROMPT_DYNAMIC_BOUNDARY__")
    }

    @Test("Default agent prompt references product")
    func testDefaultAgentPromptReferencesProduct() {
        let prompt = SystemPrompt.defaultAgentPrompt
        #expect(prompt.contains("Swift Code"), "Agent prompt should mention Swift Code")
    }

    // MARK: - SystemPromptComposer

    @Test("Composer produces non-empty output with defaults")
    func testComposerProducesNonEmptyOutput() {
        let composer = SystemPromptComposer()
        let result = composer.compose()
        #expect(!result.isEmpty)
        #expect(result == SystemPrompt.coreText)
    }

    @Test("Composer appends environment section when provided")
    func testComposerAppendsEnvironment() {
        let composer = SystemPromptComposer()
        let envSection = "# Environment\n - Primary working directory: /tmp"
        let result = composer.compose(environment: envSection)
        #expect(result.contains("# Environment"))
        #expect(result.contains("/tmp"))
    }

    @Test("Composer appends MCP server instructions")
    func testComposerAppendsMCPInstructions() {
        let composer = SystemPromptComposer()
        let server = MCPServerDescription(name: "my-mcp", instructions: "Use tool X.")
        let result = composer.compose(mcpServers: [server])
        #expect(result.contains("MCP Server Instructions"))
        #expect(result.contains("my-mcp"))
        #expect(result.contains("Use tool X."))
    }

    @Test("Composer appends language section")
    func testComposerAppendsLanguage() {
        let composer = SystemPromptComposer()
        let result = composer.compose(language: "French")
        #expect(result.contains("# Language"))
        #expect(result.contains("French"))
    }

    @Test("Composer omits empty sections")
    func testComposerOmitsEmptySections() {
        let composer = SystemPromptComposer()
        let result = composer.compose(
            environment: nil,
            toolsDescription: "",
            memory: nil,
            mcpServers: [],
            language: nil
        )
        // Should equal core text when all dynamic sections are nil/empty
        #expect(result == SystemPrompt.coreText)
        #expect(!result.contains("# Tools"))
        #expect(!result.contains("# MCP"))
    }

    @Test("Composer includes tools description when provided")
    func testComposerIncludesToolsDescription() {
        let composer = SystemPromptComposer()
        let tools = "Bash: run shell commands\nRead: read files"
        let result = composer.compose(toolsDescription: tools)
        #expect(result.contains("# Tools"))
        #expect(result.contains("Bash: run shell commands"))
    }
}
