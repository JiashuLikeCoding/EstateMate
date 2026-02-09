//
//  RootView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("已登录 ✅")
                Button("退出登录") {
                    Task { await sessionStore.signOut() }
                }
            }
            .navigationTitle("Home")
            .padding()
        }
    }
}

#Preview {
    RootView().environmentObject(SessionStore())
}
