import AsyncHTTPClient
import Foundation
import NIOCore

/// Drives the desktop OAuth 2.0 + PKCE flow against Anthropic's auth servers.
///
/// 1. `prepareAuthorization()` returns the URL to open in the browser and a
///    pending state token used to validate the callback.
/// 2. The REPL opens the URL and waits on a `CallbackServer` for the redirect.
/// 3. `exchange(code:verifier:)` posts the auth code back to the token endpoint
///    and returns a fully-populated `OAuthToken`.
public actor OAuthService {

    public struct AuthorizationRequest: Sendable {
        public let authorizeURL: URL
        public let redirectURI: URL
        public let state: String
        public let pkce: PKCE.Pair
    }

    public enum OAuthServiceError: Error, Sendable {
        case stateMismatch
        case missingCode
        case exchangeFailed(status: Int, body: String)
        case malformedTokenResponse(String)
    }

    private let clientID: String
    private let authorizeURL: URL
    private let tokenURL: URL
    private let scopes: [String]
    private let httpClient: HTTPClient
    private let ownsClient: Bool

    public init(
        clientID: String = OAuthConstants.clientID,
        authorizeURL: URL = URL(string: OAuthConstants.authorizeURL)!,
        tokenURL: URL = URL(string: OAuthConstants.tokenURL)!,
        scopes: [String] = OAuthConstants.scopes,
        httpClient: HTTPClient? = nil
    ) {
        self.clientID = clientID
        self.authorizeURL = authorizeURL
        self.tokenURL = tokenURL
        self.scopes = scopes
        if let client = httpClient {
            self.httpClient = client
            self.ownsClient = false
        } else {
            var config = HTTPClient.Configuration()
            config.timeout = HTTPClient.Configuration.Timeout(
                connect: .seconds(10),
                read: .seconds(30)
            )
            self.httpClient = HTTPClient(configuration: config)
            self.ownsClient = true
        }
    }

    /// Build the URL to open in the browser.
    public func prepareAuthorization(redirectPort: Int) -> AuthorizationRequest {
        let pkce = PKCE.generate()
        let state = PKCE.generateState()
        let redirectURI = URL(string: "http://localhost:\(redirectPort)/callback")!

        var comps = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.method),
        ]
        return AuthorizationRequest(
            authorizeURL: comps.url!,
            redirectURI: redirectURI,
            state: state,
            pkce: pkce
        )
    }

    /// Validate the callback against the expected state and extract the auth code.
    public func extractCode(
        from callback: CallbackServer.CapturedRequest,
        expectedState: String
    ) throws -> String {
        if let returnedState = callback.query["state"], returnedState != expectedState {
            throw OAuthServiceError.stateMismatch
        }
        guard let code = callback.query["code"], !code.isEmpty else {
            throw OAuthServiceError.missingCode
        }
        return code
    }

    /// Exchange the auth code for a bearer token.
    public func exchange(
        code: String,
        request: AuthorizationRequest
    ) async throws -> OAuthToken {
        var form: [String] = []
        let pairs: [(String, String)] = [
            ("grant_type", "authorization_code"),
            ("client_id", clientID),
            ("code", code),
            ("code_verifier", request.pkce.verifier),
            ("redirect_uri", request.redirectURI.absoluteString),
        ]
        for (k, v) in pairs {
            let encV = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
            form.append("\(k)=\(encV)")
        }
        let body = form.joined(separator: "&")

        var httpRequest = HTTPClientRequest(url: tokenURL.absoluteString)
        httpRequest.method = .POST
        httpRequest.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        httpRequest.headers.add(name: "Accept", value: "application/json")
        httpRequest.body = .bytes(ByteBuffer(string: body))

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))
        let status = Int(response.status.code)
        let buf = try await response.body.collect(upTo: 64 * 1024)
        let bodyString = String(buffer: buf)

        guard (200..<300).contains(status) else {
            throw OAuthServiceError.exchangeFailed(status: status, body: bodyString)
        }

        guard let data = bodyString.data(using: .utf8) else {
            throw OAuthServiceError.malformedTokenResponse(bodyString)
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let token_type: String?
            let expires_in: Int?
            let refresh_token: String?
        }

        let decoded: TokenResponse
        do {
            decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw OAuthServiceError.malformedTokenResponse(bodyString)
        }

        let expiresAt = decoded.expires_in.map { Date(timeIntervalSinceNow: TimeInterval($0)) }
        return OAuthToken(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: expiresAt,
            tokenType: decoded.token_type ?? "Bearer"
        )
    }

    public func shutdown() async {
        guard ownsClient else { return }
        try? await httpClient.shutdown()
    }
}

private extension String {
    init(buffer: ByteBuffer) {
        var b = buffer
        let bytes = b.readBytes(length: b.readableBytes) ?? []
        self = String(bytes: bytes, encoding: .utf8) ?? ""
    }
}
