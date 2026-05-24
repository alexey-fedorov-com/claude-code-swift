import XCTest
@testable import SwiftCodeTerminalUI

final class LoginReducerTests: XCTestCase {

    private func makeState(_ flow: LoginFlowState) -> ChatScreenState {
        var s = ChatScreenState(version: "test")
        s.loginFlow = flow
        return s
    }

    // MARK: - Menu

    func testMenu_PressingOneOpensApiKeyEntry() {
        var state = makeState(.menu)
        let outcome = LoginReducer.reduce(event: .character("1"), to: &state)
        XCTAssertEqual(outcome, .chooseApiKey)
        if case .apiKeyEntry(let buf) = state.loginFlow! {
            XCTAssertEqual(buf, "")
        } else {
            XCTFail("Expected .apiKeyEntry, got \(state.loginFlow!)")
        }
    }

    func testMenu_PressingTwoChoosesOAuth() {
        var state = makeState(.menu)
        let outcome = LoginReducer.reduce(event: .character("2"), to: &state)
        XCTAssertEqual(outcome, .chooseOAuth)
        // State unchanged — REPL will transition to .oauthWaiting after starting the server.
        XCTAssertEqual(state.loginFlow, .menu)
    }

    func testMenu_EscCancels() {
        var state = makeState(.menu)
        let outcome = LoginReducer.reduce(event: .escape, to: &state)
        XCTAssertEqual(outcome, .cancel)
        XCTAssertNil(state.loginFlow)
    }

    // MARK: - API Key Entry

    func testApiKeyEntry_CharsAppendToBuffer() {
        var state = makeState(.apiKeyEntry(buffer: "sk-"))
        _ = LoginReducer.reduce(event: .character("a"), to: &state)
        _ = LoginReducer.reduce(event: .character("n"), to: &state)
        _ = LoginReducer.reduce(event: .character("t"), to: &state)
        if case .apiKeyEntry(let buf) = state.loginFlow! {
            XCTAssertEqual(buf, "sk-ant")
        } else {
            XCTFail("Expected .apiKeyEntry, got \(state.loginFlow!)")
        }
    }

    func testApiKeyEntry_BackspaceRemovesLastChar() {
        var state = makeState(.apiKeyEntry(buffer: "sk-ant"))
        _ = LoginReducer.reduce(event: .backspace, to: &state)
        if case .apiKeyEntry(let buf) = state.loginFlow! {
            XCTAssertEqual(buf, "sk-an")
        } else {
            XCTFail("Expected .apiKeyEntry, got \(state.loginFlow!)")
        }
    }

    func testApiKeyEntry_PasteAppends() {
        var state = makeState(.apiKeyEntry(buffer: "sk-"))
        _ = LoginReducer.reduce(event: .paste("ant-api01-fake"), to: &state)
        if case .apiKeyEntry(let buf) = state.loginFlow! {
            XCTAssertEqual(buf, "sk-ant-api01-fake")
        } else {
            XCTFail("Expected .apiKeyEntry, got \(state.loginFlow!)")
        }
    }

    func testApiKeyEntry_EnterSubmits() {
        var state = makeState(.apiKeyEntry(buffer: "sk-ant-test"))
        let outcome = LoginReducer.reduce(event: .enter, to: &state)
        XCTAssertEqual(outcome, .submitApiKey("sk-ant-test"))
    }

    func testApiKeyEntry_EnterIgnoredWhenBufferEmpty() {
        var state = makeState(.apiKeyEntry(buffer: ""))
        let outcome = LoginReducer.reduce(event: .enter, to: &state)
        XCTAssertNil(outcome)
    }

    func testApiKeyEntry_EscCancels() {
        var state = makeState(.apiKeyEntry(buffer: "anything"))
        let outcome = LoginReducer.reduce(event: .escape, to: &state)
        XCTAssertEqual(outcome, .cancel)
        XCTAssertNil(state.loginFlow)
    }

    // MARK: - Waiting States

    func testValidating_CtrlCCancels() {
        var state = makeState(.validatingApiKey)
        let outcome = LoginReducer.reduce(event: .controlChar("c"), to: &state)
        XCTAssertEqual(outcome, .cancel)
        XCTAssertNil(state.loginFlow)
    }

    func testValidating_IgnoresOtherKeys() {
        var state = makeState(.validatingApiKey)
        let outcome = LoginReducer.reduce(event: .character("x"), to: &state)
        XCTAssertNil(outcome)
        XCTAssertEqual(state.loginFlow, .validatingApiKey)
    }

    func testOAuthWaiting_EscCancels() {
        var state = makeState(.oauthWaiting(authorizeURL: "https://example.com"))
        let outcome = LoginReducer.reduce(event: .escape, to: &state)
        XCTAssertEqual(outcome, .cancel)
        XCTAssertNil(state.loginFlow)
    }

    // MARK: - Terminal States

    func testSuccess_AnyKeyDismisses() {
        var state = makeState(.success(message: "ok"))
        let outcome = LoginReducer.reduce(event: .character("z"), to: &state)
        XCTAssertEqual(outcome, .dismiss)
        XCTAssertNil(state.loginFlow)
    }

    func testError_AnyKeyDismisses() {
        var state = makeState(.error(message: "fail"))
        let outcome = LoginReducer.reduce(event: .enter, to: &state)
        XCTAssertEqual(outcome, .dismiss)
        XCTAssertNil(state.loginFlow)
    }
}

final class LoginScreenRenderTests: XCTestCase {

    private func screenText(_ s: Screen) -> String {
        (0..<s.height).map { row in
            (0..<s.width).map { String(s.cell(at: $0, row: row).character) }.joined()
        }.joined(separator: "\n")
    }

    func testMenuRendersBothOptions() {
        let view = LoginScreen(flow: .menu, width: 60)
        let screen = renderViewToScreen(view, width: 60, height: 16)
        let text = screenText(screen)
        XCTAssertTrue(text.contains("Sign in to Anthropic"),
                      "Title missing; rendered:\n\(text)")
        XCTAssertTrue(text.contains("API key"),
                      "API key option missing; rendered:\n\(text)")
        XCTAssertTrue(text.contains("OAuth") || text.contains("browser"),
                      "OAuth option missing; rendered:\n\(text)")
    }

    func testApiKeyEntryMasksBuffer() {
        let view = LoginScreen(flow: .apiKeyEntry(buffer: "sk-ant-secret"), width: 60)
        let screen = renderViewToScreen(view, width: 60, height: 16)
        let text = screenText(screen)
        // Don't leak the cleartext
        XCTAssertFalse(text.contains("sk-ant-secret"),
                       "Cleartext key leaked into render:\n\(text)")
        // Should show bullets equal to key length
        XCTAssertTrue(text.contains("•"),
                      "Expected bullet mask; rendered:\n\(text)")
    }

    func testOAuthWaitingShowsURL() {
        let url = "https://claude.com/cai/oauth/authorize?x=1"
        let view = LoginScreen(flow: .oauthWaiting(authorizeURL: url), width: 80)
        let screen = renderViewToScreen(view, width: 80, height: 16)
        let text = screenText(screen)
        XCTAssertTrue(text.contains("claude.com"),
                      "Authorize URL host missing; rendered:\n\(text)")
    }

    func testSuccessRendersCheckmark() {
        let view = LoginScreen(flow: .success(message: "ok"), width: 60)
        let screen = renderViewToScreen(view, width: 60, height: 12)
        let text = screenText(screen)
        XCTAssertTrue(text.contains("✓"),
                      "Success checkmark missing; rendered:\n\(text)")
    }

    func testErrorRendersX() {
        let view = LoginScreen(flow: .error(message: "bad key"), width: 60)
        let screen = renderViewToScreen(view, width: 60, height: 12)
        let text = screenText(screen)
        XCTAssertTrue(text.contains("✗"),
                      "Error X missing; rendered:\n\(text)")
        XCTAssertTrue(text.contains("bad key"),
                      "Error message missing; rendered:\n\(text)")
    }
}
