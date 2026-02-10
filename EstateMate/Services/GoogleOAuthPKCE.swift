//
//  GoogleOAuthPKCE.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import AuthenticationServices
import CryptoKit
import Foundation

enum GoogleOAuthConfig {
    /// Google OAuth Client ID.
    /// NOTE: Do NOT embed client_secret in the app.
    static let clientId: String = "751209828977-r4oog4cqns0cc7ulk5cdmedgm0m9s2hq.apps.googleusercontent.com"

    /// iOS OAuth client uses reverse-client-id as the URL scheme.
    /// (From the downloaded plist: REVERSED_CLIENT_ID)
    static let redirectUri: String = "com.googleusercontent.apps.751209828977-r4oog4cqns0cc7ulk5cdmedgm0m9s2hq:/oauth"

    static var isConfigured: Bool {
        !clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !redirectUri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum GoogleOAuthPKCE {
    struct AuthorizationResult: Hashable {
        let code: String
        let codeVerifier: String
    }

    @MainActor
    static func authorize(clientId: String, redirectUri: String, scopes: [String]) async throws -> AuthorizationResult {
        let verifier = randomURLSafeString(length: 64)
        let challenge = codeChallengeS256(verifier)
        let state = randomURLSafeString(length: 24)

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: redirectUri),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scopes.joined(separator: " ")),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state)
        ]

        guard let authURL = comps.url else {
            throw OAuthError.invalidURL
        }

        guard let scheme = URL(string: redirectUri)?.scheme else {
            throw OAuthError.invalidRedirectURI
        }

        let callback = try await ASWebAuthenticationSessionBridge.authorize(url: authURL, callbackURLScheme: scheme)

        guard let callbackComps = URLComponents(url: callback, resolvingAgainstBaseURL: false) else {
            throw OAuthError.invalidCallback
        }

        let items = callbackComps.queryItems ?? []
        let returnedState = items.first(where: { $0.name == "state" })?.value
        guard returnedState == state else {
            throw OAuthError.stateMismatch
        }

        if let err = items.first(where: { $0.name == "error" })?.value {
            throw OAuthError.oauthError(err)
        }

        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw OAuthError.missingCode
        }

        return AuthorizationResult(code: code, codeVerifier: verifier)
    }

    private static func codeChallengeS256(_ verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return base64URLEncode(Data(hash))
    }

    private static func randomURLSafeString(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    enum OAuthError: LocalizedError {
        case invalidURL
        case invalidRedirectURI
        case invalidCallback
        case stateMismatch
        case missingCode
        case oauthError(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "授权链接无效"
            case .invalidRedirectURI: return "redirectUri 配置无效"
            case .invalidCallback: return "授权回调无效"
            case .stateMismatch: return "授权校验失败（state 不匹配）"
            case .missingCode: return "授权失败：未返回 code"
            case let .oauthError(s): return "授权失败：\(s)"
            }
        }
    }
}

@MainActor
final class ASWebAuthenticationSessionBridge: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: ASWebAuthenticationSession?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Best effort. Using first key window.
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }

    static func authorize(url: URL, callbackURLScheme: String) async throws -> URL {
        let bridge = ASWebAuthenticationSessionBridge()
        return try await bridge.start(url: url, callbackURLScheme: callbackURLScheme)
    }

    private func start(url: URL, callbackURLScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.continuation = continuation

            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: GoogleOAuthPKCE.OAuthError.invalidCallback)
                    return
                }
                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            _ = session.start()
        }
    }
}
