//
//  CRMGmailIntegrationService.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation
import Supabase

@MainActor
final class CRMGmailIntegrationService {
    struct Status: Codable, Hashable {
        var email: String?
        var connected: Bool
    }

    private let client = SupabaseClientProvider.client

    // Edge Function calls can hang if the function isn't deployed or the network is flaky.
    // We enforce a short timeout so UI won't get stuck in "处理中…".
    private func invokeWithTimeout<T: Decodable>(
        _ name: String,
        body: some Encodable,
        timeoutSeconds: UInt64 = 12
    ) async throws -> T {
        func invokeOnce(accessToken: String) async throws -> T {
            let headers = [
                "Authorization": "Bearer \(accessToken)"
            ]

            return try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask {
                    let res: T = try await self.client.functions.invoke(name, options: .init(headers: headers, body: body))
                    return res
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                    throw EMError.message("请求超时（Supabase Function：\(name)）。请确认已部署 gmail_* functions，并稍后重试。")
                }

                do {
                    let first = try await group.next()!
                    group.cancelAll()
                    return first
                } catch {
                    group.cancelAll()
                    throw error
                }
            }
        }

        // Make sure we pass the user's JWT to Edge Functions.
        // Some environments don't automatically attach Authorization for function calls.
        var tokenForDebug: String? = nil
        do {
            let session = try await client.auth.session
            tokenForDebug = session.accessToken
            return try await invokeOnce(accessToken: session.accessToken)
        } catch {
            let tokenInfo: String = {
                guard let t = tokenForDebug, !t.isEmpty else { return "" }
                let prefix = String(t.prefix(16))
                let len = t.count
                let iss = Self.jwtIssuer(from: t) ?? ""
                let issLine = iss.isEmpty ? "" : "\niss: \(iss)"
                return "\n\nJWT(debug): len=\(len), prefix=\(prefix)\(issLine)"
            }()
            // If we got a 401, try to refresh session once, then retry.
            if let e = error as? FunctionsError {
                switch e {
                case let .httpError(code, data):
                    // If we got a 401, try to refresh session once, then retry.
                    if code == 401 {
                        do {
                            _ = try await client.auth.refreshSession()
                            let session = try await client.auth.session
                            return try await invokeOnce(accessToken: session.accessToken)
                        } catch {
                            let serverBody = String(data: data, encoding: .utf8) ?? ""
                            let detail = serverBody.trimmingCharacters(in: .whitespacesAndNewlines)
                            if detail.isEmpty {
                                throw EMError.message("登录状态已过期或无权限（401）。请先退出登录再重新登录，然后重试连接 Gmail。")
                            } else {
                                throw EMError.message("登录状态已过期或无权限（401）。\n\n服务器返回：\n\(detail)\(tokenInfo)")
                            }
                        }
                    }

                    // Bubble up server body for easier debugging (non-401).
                    let serverBody = String(data: data, encoding: .utf8) ?? ""
                    if !serverBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        throw EMError.message("请求失败（\(code)）。\n\n服务器返回：\n\(serverBody)\(tokenInfo)")
                    }
                default:
                    break
                }
            }
            throw error
        }
    }

    private func invokeVoidWithTimeout(
        _ name: String,
        body: some Encodable,
        timeoutSeconds: UInt64 = 12
    ) async throws {
        _ = try await invokeWithTimeout(name, body: body, timeoutSeconds: timeoutSeconds) as EmptyResponse
    }

    func status() async throws -> Status {
        try await invokeWithTimeout("gmail_status", body: EmptyBody())
    }

    func disconnect() async throws {
        try await invokeVoidWithTimeout("gmail_disconnect", body: EmptyBody())
    }

    /// Interactive OAuth connect.
    /// - Note: This requires GoogleOAuthConfig to be filled. If not, throws a friendly error.
    func connectInteractive() async throws -> Status {
        guard GoogleOAuthConfig.isConfigured else {
            throw EMError.message("尚未配置 Google OAuth（需要 clientId/redirectUri）。")
        }

        let scopes: [String] = [
            "https://www.googleapis.com/auth/gmail.readonly",
            "https://www.googleapis.com/auth/gmail.send"
        ]

        let result = try await GoogleOAuthPKCE.authorize(
            clientId: GoogleOAuthConfig.clientId,
            redirectUri: GoogleOAuthConfig.redirectUri,
            scopes: scopes
        )

        struct ExchangeBody: Encodable {
            let code: String
            let codeVerifier: String
            let redirectUri: String
        }

        let body = ExchangeBody(code: result.code, codeVerifier: result.codeVerifier, redirectUri: GoogleOAuthConfig.redirectUri)
        return try await invokeWithTimeout("gmail_oauth_exchange", body: body)
    }

    // MARK: - Debug helpers

    static func jwtIssuer(from token: String) -> String? {
        // token = header.payload.signature
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payload = String(parts[1])

        func base64UrlDecode(_ s: String) -> Data? {
            var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let pad = 4 - (t.count % 4)
            if pad < 4 { t += String(repeating: "=", count: pad) }
            return Data(base64Encoded: t)
        }

        guard let data = base64UrlDecode(payload) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any] else { return nil }
        return dict["iss"] as? String
    }
}

private struct EmptyBody: Encodable {}
private struct EmptyResponse: Decodable {}

enum EMError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(s): return s
        }
    }
}
