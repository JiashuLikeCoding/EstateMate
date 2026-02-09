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

    var isLoggedIn: Bool { session != nil }

    func loadSession() async {
        do {
            self.session = try await SupabaseClientProvider.client.auth.session
        } catch {
            self.session = nil
        }
    }

    func signOut() async {
        do {
            try await SupabaseClientProvider.client.auth.signOut()
            self.session = nil
            self.selectedWorkspace = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
