import XCTest
@testable import SwiftCodeAPI
import Foundation

final class PKCETests: XCTestCase {

    func testVerifierAndChallengeAreNonEmpty() {
        let pair = PKCE.generate()
        XCTAssertFalse(pair.verifier.isEmpty)
        XCTAssertFalse(pair.challenge.isEmpty)
        XCTAssertEqual(pair.method, "S256")
    }

    /// RFC 7636 §4.1: verifier length must be 43..128 characters.
    func testVerifierLengthRespectsRFC() {
        for _ in 0..<10 {
            let pair = PKCE.generate()
            XCTAssertGreaterThanOrEqual(pair.verifier.count, 43)
            XCTAssertLessThanOrEqual(pair.verifier.count, 128)
        }
    }

    /// Base64URL forbids '+' '/' '=' characters; only A-Z a-z 0-9 - _ allowed.
    func testChallengeUsesBase64URLAlphabet() {
        for _ in 0..<10 {
            let pair = PKCE.generate()
            let bad = pair.challenge.contains("+")
                || pair.challenge.contains("/")
                || pair.challenge.contains("=")
            XCTAssertFalse(bad, "Challenge contains non-URL-safe char: \(pair.challenge)")
        }
    }

    func testVerifiersAreDistinct() {
        let a = PKCE.generate()
        let b = PKCE.generate()
        XCTAssertNotEqual(a.verifier, b.verifier)
    }

    func testStateTokenIsURLSafe() {
        let s = PKCE.generateState()
        XCTAssertFalse(s.isEmpty)
        XCTAssertFalse(s.contains("+"))
        XCTAssertFalse(s.contains("/"))
        XCTAssertFalse(s.contains("="))
    }
}

final class CallbackServerParseTests: XCTestCase {

    /// The HTTP request line parser must extract path and query.
    func testParsesCallbackQuery() {
        let raw = "GET /callback?code=abc&state=xyz HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let result = CallbackServer.parseRequestLine(raw)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, "/callback")
        XCTAssertEqual(result?.1["code"], "abc")
        XCTAssertEqual(result?.1["state"], "xyz")
    }

    func testHandlesPercentEncoding() {
        let raw = "GET /callback?code=a%2Fb%3Dc&state=hello%20world HTTP/1.1\r\n\r\n"
        let result = CallbackServer.parseRequestLine(raw)
        XCTAssertEqual(result?.1["code"], "a/b=c")
        XCTAssertEqual(result?.1["state"], "hello world")
    }

    func testHandlesNoQueryString() {
        let raw = "GET / HTTP/1.1\r\n\r\n"
        let result = CallbackServer.parseRequestLine(raw)
        XCTAssertEqual(result?.0, "/")
        XCTAssertEqual(result?.1.count, 0)
    }
}

final class OAuthServiceTests: XCTestCase {

    func testPrepareAuthorizationProducesValidURL() async {
        let service = OAuthService()
        let req = await service.prepareAuthorization(redirectPort: 12345)
        XCTAssertTrue(req.authorizeURL.absoluteString.hasPrefix("https://"),
                      "Authorize URL must be HTTPS: \(req.authorizeURL)")

        let comps = URLComponents(url: req.authorizeURL, resolvingAgainstBaseURL: false)!
        let items = Dictionary(uniqueKeysWithValues:
            (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["client_id"], OAuthConstants.clientID)
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertNotNil(items["state"])
        XCTAssertNotNil(items["code_challenge"])
        XCTAssertTrue(items["redirect_uri"]?.contains("localhost:12345") ?? false,
                      "Redirect URI should embed the local port; got \(items["redirect_uri"] ?? "")")

        await service.shutdown()
    }

    func testExtractCodeRejectsMismatchedState() async {
        let service = OAuthService()
        let req = await service.prepareAuthorization(redirectPort: 12345)
        let bad = CallbackServer.CapturedRequest(
            path: "/callback",
            query: ["code": "abc", "state": "wrong-state"]
        )
        do {
            _ = try await service.extractCode(from: bad, expectedState: req.state)
            XCTFail("Expected stateMismatch error")
        } catch OAuthService.OAuthServiceError.stateMismatch {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        await service.shutdown()
    }

    func testExtractCodeRequiresCode() async {
        let service = OAuthService()
        let req = await service.prepareAuthorization(redirectPort: 12345)
        let bad = CallbackServer.CapturedRequest(
            path: "/callback",
            query: ["state": req.state]
        )
        do {
            _ = try await service.extractCode(from: bad, expectedState: req.state)
            XCTFail("Expected missingCode error")
        } catch OAuthService.OAuthServiceError.missingCode {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        await service.shutdown()
    }
}
