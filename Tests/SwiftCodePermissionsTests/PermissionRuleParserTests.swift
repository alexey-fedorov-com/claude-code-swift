import XCTest
@testable import SwiftCodePermissions

final class PermissionRuleParserTests: XCTestCase {

    // MARK: - permissionRuleValueFromString

    func testParseToolNameOnly() {
        let rule = permissionRuleValueFromString("Bash")
        XCTAssertEqual(rule.toolName, "Bash")
        XCTAssertNil(rule.ruleContent)
    }

    func testParseToolWithExactContent() {
        let rule = permissionRuleValueFromString("Bash(git push)")
        XCTAssertEqual(rule.toolName, "Bash")
        XCTAssertEqual(rule.ruleContent, "git push")
    }

    func testParseToolWithWildcardContent() {
        let rule = permissionRuleValueFromString("Bash(git *)")
        XCTAssertEqual(rule.toolName, "Bash")
        XCTAssertEqual(rule.ruleContent, "git *")
    }

    func testParseReadToolWithPathGlob() {
        let rule = permissionRuleValueFromString("Read(/etc/*)")
        XCTAssertEqual(rule.toolName, "Read")
        XCTAssertEqual(rule.ruleContent, "/etc/*")
    }

    func testParseToolWithEmptyParens() {
        // Bash() → tool-wide rule, no content
        let rule = permissionRuleValueFromString("Bash()")
        XCTAssertEqual(rule.toolName, "Bash")
        XCTAssertNil(rule.ruleContent)
    }

    func testParseToolWithBareWildcardParens() {
        // Bash(*) → tool-wide rule, no content
        let rule = permissionRuleValueFromString("Bash(*)")
        XCTAssertEqual(rule.toolName, "Bash")
        XCTAssertNil(rule.ruleContent)
    }

    func testParseToolWithEscapedParens() {
        // Bash(python -c "print\(1\)") → ruleContent = python -c "print(1)"
        let rule = permissionRuleValueFromString(#"Bash(python -c "print\(1\)")"#)
        XCTAssertEqual(rule.toolName, "Bash")
        XCTAssertEqual(rule.ruleContent, #"python -c "print(1)""#)
    }

    func testParseMalformedNoClosingParen() {
        // No closing paren → treat as tool name
        let rule = permissionRuleValueFromString("Bash(npm install")
        XCTAssertEqual(rule.toolName, "Bash(npm install")
        XCTAssertNil(rule.ruleContent)
    }

    func testParseMissingToolName() {
        // (foo) → no tool name → treat whole thing as tool name
        let rule = permissionRuleValueFromString("(foo)")
        XCTAssertEqual(rule.toolName, "(foo)")
        XCTAssertNil(rule.ruleContent)
    }

    func testParseLegacyToolName_Task() {
        // "Task" should map to canonical "Agent"
        let rule = permissionRuleValueFromString("Task")
        XCTAssertEqual(rule.toolName, "Agent")
    }

    func testParseLegacyToolName_KillShell() {
        let rule = permissionRuleValueFromString("KillShell")
        XCTAssertEqual(rule.toolName, "TaskStop")
    }

    // MARK: - permissionRuleValueToString

    func testStringifyToolNameOnly() {
        let rule = PermissionRuleValue(toolName: "Bash")
        XCTAssertEqual(permissionRuleValueToString(rule), "Bash")
    }

    func testStringifyToolWithContent() {
        let rule = PermissionRuleValue(toolName: "Bash", ruleContent: "npm install")
        XCTAssertEqual(permissionRuleValueToString(rule), "Bash(npm install)")
    }

    func testStringifyToolWithParensInContent() {
        let rule = PermissionRuleValue(toolName: "Bash", ruleContent: "python -c \"print(1)\"")
        // Parens in content get escaped
        XCTAssertTrue(permissionRuleValueToString(rule).contains("\\("))
        XCTAssertTrue(permissionRuleValueToString(rule).contains("\\)"))
    }

    func testRoundTrip() {
        let original = "Bash(git commit -m \"fix\\(typo\\)\")"
        let parsed = permissionRuleValueFromString(original)
        let serialized = permissionRuleValueToString(parsed)
        let reparsed = permissionRuleValueFromString(serialized)
        XCTAssertEqual(parsed.toolName, reparsed.toolName)
        XCTAssertEqual(parsed.ruleContent, reparsed.ruleContent)
    }

    // MARK: - Wildcard matching

    func testWildcardMatchesExactPrefix() {
        // "git *" matches "git push"
        XCTAssertTrue(matchWildcardPattern("git *", command: "git push"))
    }

    func testWildcardMatchesAnotherSubcommand() {
        // "git *" matches "git status"
        XCTAssertTrue(matchWildcardPattern("git *", command: "git status"))
    }

    func testWildcardDoesNotMatchUnrelatedCommand() {
        // "git *" does NOT match "ls"
        XCTAssertFalse(matchWildcardPattern("git *", command: "ls"))
    }

    func testWildcardMatchesBarePrefix() {
        // "git *" with trailing space+wildcard also matches bare "git" (optional args)
        XCTAssertTrue(matchWildcardPattern("git *", command: "git"))
    }

    func testExactRuleMatchesExactly() {
        XCTAssertTrue(shellRuleMatches(ruleContent: "git push", command: "git push"))
        XCTAssertFalse(shellRuleMatches(ruleContent: "git push", command: "git push --force"))
    }

    func testPrefixRuleMatchesPrefixedCommands() {
        // Legacy :* syntax
        XCTAssertTrue(shellRuleMatches(ruleContent: "git:*", command: "git commit"))
        XCTAssertTrue(shellRuleMatches(ruleContent: "git:*", command: "git push --force"))
        XCTAssertFalse(shellRuleMatches(ruleContent: "git:*", command: "ls"))
    }

    func testPrefixRuleDoesNotMatchDifferentCommand() {
        XCTAssertFalse(shellRuleMatches(ruleContent: "npm:*", command: "node index.js"))
    }

    func testWildcardInMiddleOfPattern() {
        XCTAssertTrue(matchWildcardPattern("git * --force", command: "git push --force"))
        XCTAssertFalse(matchWildcardPattern("git * --force", command: "git push"))
    }

    func testEscapedStarMatchesLiteralStar() {
        XCTAssertTrue(matchWildcardPattern(#"echo \*"#, command: "echo *"))
        XCTAssertFalse(matchWildcardPattern(#"echo \*"#, command: "echo hello"))
    }

    // MARK: - parsePermissionRule

    func testParsePermissionRuleExact() {
        let rule = parsePermissionRule("git push")
        if case .exact(let cmd) = rule {
            XCTAssertEqual(cmd, "git push")
        } else {
            XCTFail("Expected exact rule")
        }
    }

    func testParsePermissionRulePrefix() {
        let rule = parsePermissionRule("git:*")
        if case .prefix(let p) = rule {
            XCTAssertEqual(p, "git")
        } else {
            XCTFail("Expected prefix rule")
        }
    }

    func testParsePermissionRuleWildcard() {
        let rule = parsePermissionRule("git *")
        if case .wildcard(let pattern) = rule {
            XCTAssertEqual(pattern, "git *")
        } else {
            XCTFail("Expected wildcard rule")
        }
    }
}
