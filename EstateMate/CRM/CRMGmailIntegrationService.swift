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

    struct ContactMessagesResponse: Codable, Hashable {
        struct DebugInfo: Codable, Hashable {
            var me: String
            var contactEmail: String
            var q: String
            var fetched: Int
            var kept: Int
        }
        struct Item: Codable, Hashable, Identifiable {
            var id: String
            var threadId: String?
            var direction: String
            var subject: String
            var from: String
            var to: String
            var date: String
            var snippet: String
            var internalDate: String?
        }

        var ok: Bool
        var messages: [Item]
        var debug: DebugInfo?
    }

    struct MessageGetResponse: Codable, Hashable {
        struct Body: Codable, Hashable {
            var mimeType: String
            var text: String
        }

        var ok: Bool
        var id: String
        var threadId: String?
        var subject: String
        var from: String
        var to: String
        var date: String
        var snippet: String
        var internalDate: String?
        var messageId: String?
        var references: String?
        var body: Body
    }

    struct SendResponse: Codable, Hashable {
        var ok: Bool
        var alreadySent: Bool?
        var id: String?
    }

    // MARK: - Presentation helpers

    static func formatMessageDate(dateHeader: String, internalDate: String?) -> String {
        if let internalDate, let ms = Double(internalDate) {
            let d = Date(timeIntervalSince1970: ms / 1000.0)
            return d.formatted(.dateTime.year().month().day().hour().minute())
        }

        let raw = dateHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "—" }

        // Try common RFC2822-ish formats.
        let fmts: [String] = [
            "EEE, d MMM yyyy HH:mm:ss Z", // Tue, 10 Feb 2026 13:16:00 -0800
            "d MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm Z",
            "d MMM yyyy HH:mm Z"
        ]

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")

        for f in fmts {
            parser.dateFormat = f
            if let d = parser.date(from: raw) {
                return d.formatted(.dateTime.year().month().day().hour().minute())
            }
        }

        // Fallback: keep header but strip the timezone suffix so it doesn't look like an error.
        // e.g. "... -0800" → "..."
        if let r = raw.range(of: " [+-]\\d{4}$", options: .regularExpression) {
            return String(raw[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return raw
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
            // IMPORTANT:
            // - Use the SDK's built-in auth header setter, instead of manually passing Authorization in options.
            //   We've seen environments where passing Authorization via options doesn't override the client's
            //   internal header cleanly, leading to 401 Invalid JWT.
            self.client.functions.setAuth(token: accessToken)

            let headers = [
                // Some Supabase Edge Function gateways require the API key header.
                "apikey": SupabaseClientProvider.anonKey,
                // Some proxies/providers use x-api-key instead.
                "x-api-key": SupabaseClientProvider.anonKey
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
    func contactMessages(contactEmail: String, max: Int = 20) async throws -> ContactMessagesResponse {
        struct Body: Encodable {
            let contactEmail: String
            let max: Int
        }
        return try await invokeWithTimeout("gmail_contact_messages", body: Body(contactEmail: contactEmail, max: max))
    }

    func messageGet(messageId: String) async throws -> MessageGetResponse {
        struct Body: Encodable { let messageId: String }
        return try await invokeWithTimeout("gmail_message_get", body: Body(messageId: messageId))
    }

    func sendMessage(
        to: String,
        subject: String,
        text: String,
        html: String?,
        submissionId: String,
        threadId: String?,
        inReplyTo: String?,
        references: String?
    ) async throws -> SendResponse {
        struct Body: Encodable {
            let to: String
            let subject: String
            let text: String
            let html: String?
            let submissionId: String
            let threadId: String?
            let inReplyTo: String?
            let references: String?
        }
        return try await invokeWithTimeout(
            "gmail_send",
            body: Body(
                to: to,
                subject: subject,
                text: text,
                html: html,
                submissionId: submissionId,
                threadId: threadId,
                inReplyTo: inReplyTo,
                references: references
            )
        )
    }

    func sendTestMessage(
        to: String,
        subject: String,
        text: String,
        html: String?,
        workspace: EstateMateWorkspaceKind = .openhouse
    ) async throws -> SendResponse {
        struct Body: Encodable {
            let to: String
            let subject: String
            let text: String
            let html: String?
            let workspace: String
        }

        return try await invokeWithTimeout(
            "gmail_send_test",
            body: Body(
                to: to,
                subject: subject,
                text: text,
                html: html,
                workspace: workspace.rawValue
            )
        )
    }

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
