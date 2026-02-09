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
#if DEBUG
            // Debug convenience: always land on workspace picker after login.
            // (Still requires login; we just ensure selectedWorkspace is cleared.)
            if sessionStore.isLoggedIn {
                WorkspacePickerView()
                    .task { sessionStore.selectedWorkspace = nil }
            } else {
                LoginView()
            }
#else
            if !sessionStore.isLoggedIn {
                LoginView()
            } else if sessionStore.selectedWorkspace == nil {
                WorkspacePickerView()
            } else {
                MainView()
            }
#endif
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
            ZStack {
                AuthBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("客户管理")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                            Text("内部管理（占位页：后续加线索/房源/任务/设置）")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.72))
                        }

                        AuthCard {
                            Text("CRM 模块开发中…")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                Task { await sessionStore.signOut() }
                            } label: {
                                Text("退出登录")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    RootView().environmentObject(SessionStore())
}
