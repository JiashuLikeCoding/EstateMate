//
//  AuthService.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import Foundation
import Supabase

@MainActor
final class AuthService {
    private let client = SupabaseClientProvider.client

    /// Must match your app URL scheme.
    private let redirectToURL = URL(string: "estatemate://auth-callback")!

    func signUpEmail(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
    }

    func signInEmail(email: String, password: String) async throws -> Session {
        // Newer supabase-swift returns Session directly.
        return try await client.auth.signIn(email: email, password: password)
    }

    // MARK: - OAuth

    /// Uses supabase-swift's built-in ASWebAuthenticationSession flow.
    func signInWithOAuth(provider: Provider) async throws -> Session {
        // Using ASWebAuthenticationSession internally (supabase-swift).
        // For Google, force account chooser every time (instead of silently reusing the last account).
        let queryParams: [(name: String, value: String?)]
        if provider == .google {
            queryParams = [(name: "prompt", value: "select_account")]
        } else {
            queryParams = []
        }

        return try await client.auth.signInWithOAuth(
            provider: provider,
            redirectTo: redirectToURL,
            scopes: nil,
            queryParams: queryParams
        )
    }

    /// Only needed if you implement a custom OAuth flow with `getOAuthSignInURL`.
    func handleOAuthCallback(url: URL) async throws -> Session {
        try await client.auth.session(from: url)
    }
}
