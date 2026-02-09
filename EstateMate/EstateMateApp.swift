//
//  EstateMateApp.swift
//  EstateMate
//
//  Created by Jason Li on 2026-02-09.
//

import SwiftUI

@main
struct EstateMateApp: App {
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionStore)
                .task { await sessionStore.loadSession() }
        }
    }
}
