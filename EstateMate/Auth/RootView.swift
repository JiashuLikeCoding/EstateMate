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
            } else if !sessionStore.isGmailConnected {
                GmailRequiredGateView()
            } else if sessionStore.selectedWorkspace == nil {
                WorkspacePickerView()
            } else {
                MainView()
            }
        }
        .task {
            // Ensure we have latest status after cold start.
            if sessionStore.isLoggedIn {
                await sessionStore.refreshGmailStatus()
            }
        }
    }
}

private struct GmailRequiredGateView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            CRMGmailConnectView(autoStartConnect: false) { email in
                sessionStore.gmailEmail = email
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("退出登录") {
                        Task { await sessionStore.signOut() }
                    }
                }
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
            EMScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("客户管理", subtitle: "线索、客户、任务（开发中）")

                        EMCard {
                            NavigationLink {
                                CRMContactsListView()
                            } label: {
                                row(title: "客户列表", subtitle: "查看与搜索客户")
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(EMTheme.line)

                            NavigationLink {
                                CRMContactEditView(mode: .create)
                            } label: {
                                row(title: "新增客户", subtitle: "快速录入一位客户")
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(EMTheme.line)

                            NavigationLink {
                                CRMTasksListView()
                            } label: {
                                row(title: "待办任务", subtitle: "跟进提醒与记录")
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(EMTheme.line)

                            NavigationLink {
                                EmailTemplatesListView(workspace: .crm)
                            } label: {
                                row(title: "邮件模版", subtitle: "创建可复用的邮件内容")
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            sessionStore.selectedWorkspace = nil
                        } label: {
                            Text("返回选择系统")
                        }
                        .buttonStyle(EMSecondaryButtonStyle())

                        Spacer(minLength: 20)
                    }
                    .padding(EMTheme.padding)
                }
            }
        }
    }

    private func row(title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(EMTheme.ink2)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}

#Preview {
    RootView().environmentObject(SessionStore())
}
