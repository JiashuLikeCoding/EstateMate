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
            if !sessionStore.isLoggedIn {
                LoginView()
            } else if sessionStore.selectedWorkspace == nil {
                WorkspacePickerView()
            } else {
                MainView()
            }
        }
    }
}

struct MainView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        switch sessionStore.selectedWorkspace {
        case .openHouse:
            OpenHouseHomeView()
        case .crm:
            CRMHomeView()
        case .none:
            WorkspacePickerView()
        }
    }
}

struct CRMHomeView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("CRM")
                    .font(.title.bold())
                Text("Internal management (placeholder)")
                    .foregroundStyle(.secondary)

                Button("Sign out") {
                    Task { await sessionStore.signOut() }
                }
            }
            .padding()
        }
    }
}

#Preview {
    RootView().environmentObject(SessionStore())
}
