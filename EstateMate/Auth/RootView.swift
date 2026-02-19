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
            EMScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("客户管理", subtitle: "线索、客户、任务（开发中）")

                        EMCard {
                            NavigationLink {
                                CRMContactsListView()
                            } label: {
                                row(icon: "person.2", title: "客户列表", subtitle: "查看与搜索客户")
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(EMTheme.line)

                            NavigationLink {
                                CRMContactEditView(mode: .create)
                            } label: {
                                row(icon: "person.badge.plus", title: "新增客户", subtitle: "快速录入一位客户")
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(EMTheme.line)

                            NavigationLink {
                                CRMTasksListView()
                            } label: {
                                row(icon: "checklist", title: "待办任务", subtitle: "跟进提醒与记录")
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

    private func row(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(EMTheme.accent)
                .frame(width: 32, height: 32)
                .background(EMTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
