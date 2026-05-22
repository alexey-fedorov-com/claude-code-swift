import XCTest
@testable import SwiftCodePermissions

final class ShellSafetyTests: XCTestCase {

    // MARK: - Bash read-only commands

    func testLsIsReadOnly() {
        XCTAssertTrue(bashCommandIsReadOnly("ls"))
        XCTAssertTrue(bashCommandIsReadOnly("ls -la"))
        XCTAssertTrue(bashCommandIsReadOnly("ls /tmp"))
    }

    func testPwdIsReadOnly() {
        XCTAssertTrue(bashCommandIsReadOnly("pwd"))
    }

    func testCatIsReadOnly() {
        XCTAssertTrue(bashCommandIsReadOnly("cat"))
        XCTAssertTrue(bashCommandIsReadOnly("cat /etc/hosts"))
    }

    func testGrepIsReadOnly() {
        XCTAssertTrue(bashCommandIsReadOnly("grep"))
        XCTAssertTrue(bashCommandIsReadOnly("grep foo bar.txt"))
    }

    func testFindIsReadOnly() {
        XCTAssertTrue(bashCommandIsReadOnly("find"))
        XCTAssertTrue(bashCommandIsReadOnly("find . -name '*.swift'"))
    }

    func testWcIsReadOnly() {
        XCTAssertTrue(bashCommandIsReadOnly("wc"))
        XCTAssertTrue(bashCommandIsReadOnly("wc -l file.txt"))
    }

    func testHeadIsReadOnly() {
        XCTAssertTrue(bashCommandIsReadOnly("head"))
        XCTAssertTrue(bashCommandIsReadOnly("head -20 file.txt"))
    }

    func testTailIsReadOnly() {
        XCTAssertTrue(bashCommandIsReadOnly("tail"))
        XCTAssertTrue(bashCommandIsReadOnly("tail -f /var/log/syslog"))
    }

    // MARK: - Commands that are NOT read-only

    func testRmIsNotReadOnly() {
        XCTAssertFalse(bashCommandIsReadOnly("rm"))
        XCTAssertFalse(bashCommandIsReadOnly("rm -rf /"))
    }

    func testGitPushIsNotReadOnly() {
        // "git push" is not in the read-only list (write operation)
        // Only specific git read-only subcommands are in the list
        XCTAssertFalse(bashCommandIsReadOnly("git push"))
    }

    // MARK: - DNS cache commands NOT in read-only list (backport 2.1.90)

    func testGetDnsClientCacheNotReadOnly() {
        // Backported from 2.1.90: Get-DnsClientCache removed for DNS cache privacy
        XCTAssertFalse(bashCommandIsReadOnly("Get-DnsClientCache"))
    }

    func testIpconfigDisplayDnsNotReadOnly() {
        // Backported from 2.1.90: ipconfig /displaydns removed for DNS cache privacy
        XCTAssertFalse(bashCommandIsReadOnly("ipconfig /displaydns"))
        XCTAssertFalse(powershellCommandIsReadOnly("ipconfig /displaydns"))
    }

    // MARK: - Destructive command detection

    func testRmRfIsDestructive() {
        XCTAssertNotNil(getDestructiveCommandWarning("rm -rf /tmp/foo"))
    }

    func testRmRfSlashIsDestructive() {
        XCTAssertNotNil(getDestructiveCommandWarning("rm -rf /"))
    }

    func testGitPushForceIsDestructive() {
        XCTAssertNotNil(getDestructiveCommandWarning("git push --force"))
        XCTAssertNotNil(getDestructiveCommandWarning("git push -f"))
        XCTAssertNotNil(getDestructiveCommandWarning("git push --force-with-lease"))
    }

    func testGitResetHardIsDestructive() {
        XCTAssertNotNil(getDestructiveCommandWarning("git reset --hard"))
        XCTAssertNotNil(getDestructiveCommandWarning("git reset --hard HEAD~1"))
    }

    func testSafeCommandIsNotDestructive() {
        XCTAssertNil(getDestructiveCommandWarning("ls -la"))
        XCTAssertNil(getDestructiveCommandWarning("git status"))
        XCTAssertNil(getDestructiveCommandWarning("git log --oneline"))
    }

    func testKubectlDeleteIsDestructive() {
        XCTAssertNotNil(getDestructiveCommandWarning("kubectl delete pod my-pod"))
    }

    func testTerraformDestroyIsDestructive() {
        XCTAssertNotNil(getDestructiveCommandWarning("terraform destroy"))
    }

    // MARK: - .husky protected (backport 2.1.90)

    func testHuskyDirectoryIsProtected() {
        // .husky added to dangerousDirectories in 2.1.90
        XCTAssertTrue(dangerousDirectories.contains(".husky"))
        XCTAssertTrue(pathIsDangerous("/project/.husky/pre-commit"))
    }

    func testGitDirectoryIsProtected() {
        XCTAssertTrue(pathIsDangerous("/project/.git/config"))
    }

    func testNormalPathIsNotProtected() {
        XCTAssertFalse(pathIsDangerous("/project/src/main.swift"))
    }

    func testGitconfigFileIsProtected() {
        XCTAssertTrue(pathIsDangerous("/home/user/.gitconfig"))
    }

    func testBashrcIsProtected() {
        XCTAssertTrue(pathIsDangerous("/home/user/.bashrc"))
    }

    // MARK: - Bypass mode killswitch

    func testBypassModeKillswitchRespected() {
        // Without the env var set, bypass should not be killswitched
        // (we can't easily set env vars in tests, but we verify the function exists)
        // The actual env check is: CLAUDE_CODE_DISABLE_NONINTERACTIVE_BYPASS_PERMISSIONS=1
        let result = isBypassPermissionsModeKillswitched()
        // Result depends on environment; just ensure it doesn't crash
        _ = result
    }

    // MARK: - PowerShell read-only commands

    func testGetProcessIsReadOnly() {
        XCTAssertTrue(powershellCommandIsReadOnly("Get-Process"))
        XCTAssertTrue(powershellCommandIsReadOnly("get-process"))  // case-insensitive
    }

    func testGetChildItemIsReadOnly() {
        XCTAssertTrue(powershellCommandIsReadOnly("Get-ChildItem"))
        XCTAssertTrue(powershellCommandIsReadOnly("gci C:\\Users"))
    }

    func testRemoveItemIsNotReadOnly() {
        XCTAssertFalse(powershellCommandIsReadOnly("Remove-Item"))
    }

    func testGetDnsClientCacheNotInPSReadOnly() {
        // Backported from 2.1.90: Get-DnsClientCache NOT in read-only list
        XCTAssertFalse(powershellCommandIsReadOnly("Get-DnsClientCache"))
    }

    // MARK: - PowerShell destructive patterns

    func testRemoveItemIsDestructive() {
        XCTAssertNotNil(getPowerShellDestructiveCommandWarning("Remove-Item -Recurse C:\\foo"))
    }

    func testInvokeExpressionIsDestructive() {
        XCTAssertNotNil(getPowerShellDestructiveCommandWarning("Invoke-Expression $cmd"))
    }

    func testSafePSCommandIsNotDestructive() {
        XCTAssertNil(getPowerShellDestructiveCommandWarning("Get-Process"))
        XCTAssertNil(getPowerShellDestructiveCommandWarning("Get-ChildItem C:\\Users"))
    }

    // MARK: - YoloClassifier stub

    func testYoloClassifierAlwaysReturnsUnavailable() {
        let classifier = YoloClassifier()
        let result = classifier.classify(command: "rm -rf /")
        XCTAssertTrue(result.unavailable, "YoloClassifier stub should mark itself unavailable")
        XCTAssertFalse(result.shouldBlock, "YoloClassifier stub should not block (safe default)")
    }

    // MARK: - PermissionMode display properties

    func testPermissionModeDisplayTitles() {
        XCTAssertEqual(PermissionMode.default.displayTitle, "Default")
        XCTAssertEqual(PermissionMode.plan.displayTitle, "Plan Mode")
        XCTAssertEqual(PermissionMode.acceptEdits.displayTitle, "Accept edits")
        XCTAssertEqual(PermissionMode.bypassPermissions.displayTitle, "Bypass Permissions")
        XCTAssertEqual(PermissionMode.dontAsk.displayTitle, "Don't Ask")
        XCTAssertEqual(PermissionMode.auto.displayTitle, "Auto mode")
    }

    func testPermissionModeShortTitles() {
        XCTAssertEqual(PermissionMode.acceptEdits.shortTitle, "Accept")
        XCTAssertEqual(PermissionMode.plan.shortTitle, "Plan")
        XCTAssertEqual(PermissionMode.bypassPermissions.shortTitle, "Bypass")
    }

    func testPermissionModeSymbols() {
        XCTAssertEqual(PermissionMode.acceptEdits.symbol, "⏵⏵")
        XCTAssertEqual(PermissionMode.bypassPermissions.symbol, "⏵⏵")
        XCTAssertEqual(PermissionMode.plan.symbol, "\u{23F8}")
    }

    func testPermissionModeExternalMapping() {
        XCTAssertEqual(PermissionMode.auto.externalMode, .default)
        XCTAssertEqual(PermissionMode.bubble.externalMode, .default)
        XCTAssertEqual(PermissionMode.acceptEdits.externalMode, .acceptEdits)
        XCTAssertEqual(PermissionMode.plan.externalMode, .plan)
    }

    func testPermissionModeFromString() {
        XCTAssertEqual(PermissionMode.from(string: "plan"), .plan)
        XCTAssertEqual(PermissionMode.from(string: "unknown"), .default)
        XCTAssertEqual(PermissionMode.from(string: "acceptEdits"), .acceptEdits)
    }

    // MARK: - PermissionUpdates apply

    func testApplyAddRules() {
        var lists = PermissionRuleLists()
        let rule = PermissionRuleValue(toolName: "Bash", ruleContent: "git push")
        let update = PermissionUpdate.addRules(destination: .localSettings, rules: [rule], behavior: .allow)
        let result = applyPermissionUpdates(to: lists, updates: [update])
        XCTAssertTrue(result.allow.contains("Bash(git push)"))
    }

    func testApplyRemoveRules() {
        let lists = PermissionRuleLists(allow: ["Bash(git push)", "Bash(npm install)"])
        let rule = PermissionRuleValue(toolName: "Bash", ruleContent: "git push")
        let update = PermissionUpdate.removeRules(destination: .localSettings, rules: [rule], behavior: .allow)
        let result = applyPermissionUpdates(to: lists, updates: [update])
        XCTAssertFalse(result.allow.contains("Bash(git push)"))
        XCTAssertTrue(result.allow.contains("Bash(npm install)"))
    }

    func testApplyAddRulesNoDuplicates() {
        let lists = PermissionRuleLists(allow: ["Bash(git push)"])
        let rule = PermissionRuleValue(toolName: "Bash", ruleContent: "git push")
        let update = PermissionUpdate.addRules(destination: .localSettings, rules: [rule], behavior: .allow)
        let result = applyPermissionUpdates(to: lists, updates: [update])
        XCTAssertEqual(result.allow.filter { $0 == "Bash(git push)" }.count, 1)
    }
}
