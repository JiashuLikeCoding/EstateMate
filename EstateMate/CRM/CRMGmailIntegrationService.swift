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

    func status() async throws -> Status {
        let status: Status = try await client.functions.invoke(
            "gmail_status",
            options: .init(body: EmptyBody())
        )
        return status
    }

    func disconnect() async throws {
        _ = try await client.functions.invoke(
            "gmail_disconnect",
            options: .init(body: EmptyBody())
        )
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
        let status: Status = try await client.functions.invoke(
            "gmail_oauth_exchange",
            options: .init(body: body)
        )
        return status
    }
}

private struct EmptyBody: Encodable {}

enum EMError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(s): return s
        }
    }
}
