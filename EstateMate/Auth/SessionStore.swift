//
//  SessionStore.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import Foundation
import Combine
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    @Published var session: Session?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var selectedWorkspace: Workspace? = nil

    // 强制 Gmail 连接（用于 Gmail API 同步/发送）
    @Published var gmailEmail: String? = nil
    @Published var isGmailStatusLoading: Bool = false

    var isLoggedIn: Bool { session != nil }
    var isGmailConnected: Bool { gmailEmail != nil }

    func loadSession() async {
        do {
            self.session = try await SupabaseClientProvider.client.auth.session
        } catch {
            self.session = nil
        }

        if self.session != nil {
            await refreshGmailStatus()
        } else {
            self.gmailEmail = nil
        }
    }

    func refreshGmailStatus() async {
        guard session != nil else {
            gmailEmail = nil
            return
        }

        isGmailStatusLoading = true
        defer { isGmailStatusLoading = false }

        do {
            let status = try await CRMGmailIntegrationService().status()
            gmailEmail = status.email
        } catch {
            // Status endpoint may not exist yet; keep as not-connected but avoid spamming.
            gmailEmail = nil
        }
    }

    func signOut() async {
        do {
            try await SupabaseClientProvider.client.auth.signOut()
            self.session = nil
            self.selectedWorkspace = nil
            self.gmailEmail = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
