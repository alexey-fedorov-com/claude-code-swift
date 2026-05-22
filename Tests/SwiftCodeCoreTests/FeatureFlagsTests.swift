import XCTest
@testable import SwiftCodeCore

final class FeatureFlagsTests: XCTestCase {
    func testEnabledFlagsMatchReferenceBuildTs() {
        XCTAssertTrue(FeatureFlags.isEnabled(.voiceMode))
        XCTAssertTrue(FeatureFlags.isEnabled(.coordinatorMode))
        XCTAssertTrue(FeatureFlags.isEnabled(.tokenBudget))
        XCTAssertTrue(FeatureFlags.isEnabled(.teamMemory))
        XCTAssertTrue(FeatureFlags.isEnabled(.agentTriggers))
        XCTAssertTrue(FeatureFlags.isEnabled(.messageActions))
        XCTAssertTrue(FeatureFlags.isEnabled(.hookPrompts))
        XCTAssertTrue(FeatureFlags.isEnabled(.awaySummary))
        XCTAssertTrue(FeatureFlags.isEnabled(.backgroundSessions))
        XCTAssertTrue(FeatureFlags.isEnabled(.buddy))
        XCTAssertTrue(FeatureFlags.isEnabled(.dumpSystemPrompt))
        XCTAssertTrue(FeatureFlags.isEnabled(.coworkerTypeTelemetry))
    }

    func testDisabledFlagsMatchReferenceBuildTs() {
        XCTAssertFalse(FeatureFlags.isEnabled(.ultraplan))
        XCTAssertFalse(FeatureFlags.isEnabled(.bridgeMode))
        XCTAssertFalse(FeatureFlags.isEnabled(.chicagoMCP))
        XCTAssertFalse(FeatureFlags.isEnabled(.transcriptClassifier))
        XCTAssertFalse(FeatureFlags.isEnabled(.kairos))
        XCTAssertFalse(FeatureFlags.isEnabled(.kairosBrief))
        XCTAssertFalse(FeatureFlags.isEnabled(.proactive))
        XCTAssertFalse(FeatureFlags.isEnabled(.workflowScripts))
        XCTAssertFalse(FeatureFlags.isEnabled(.webBrowserTool))
        XCTAssertFalse(FeatureFlags.isEnabled(.terminalPanel))
        XCTAssertFalse(FeatureFlags.isEnabled(.experimentalSkillSearch))
        XCTAssertFalse(FeatureFlags.isEnabled(.historySnip))
        XCTAssertFalse(FeatureFlags.isEnabled(.cachedMicrocompact))
        XCTAssertFalse(FeatureFlags.isEnabled(.ablationBaseline))
        XCTAssertFalse(FeatureFlags.isEnabled(.overflowTestTool))
    }
}
