//
//  WorkspacePickerView.swift
//  EstateMate
//

import SwiftUI

struct WorkspacePickerView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            EMScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("选择系统", subtitle: "选择要进入的模块")

                        EMCard {
                            ForEach(Workspace.allCases) { w in
                                Button {
                                    sessionStore.selectedWorkspace = w
                                } label: {
                                    HStack(alignment: .center, spacing: 12) {
                                        Image(systemName: w.iconSystemName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(EMTheme.accent)
                                            .frame(width: 32, height: 32)
                                            .background(EMTheme.accent.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(w.title)
                                                .font(.headline)
                                            Text(w.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(EMTheme.ink2)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)

                                Divider().overlay(EMTheme.line)
                            }

                            NavigationLink {
                                CRMGmailConnectView()
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: "envelope")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(EMTheme.accent)
                                        .frame(width: 32, height: 32)
                                        .background(EMTheme.accent.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("邮箱绑定")
                                            .font(.headline)
                                        Text("连接 Gmail，用于自动发送与同步邮件往来")
                                            .font(.caption)
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(EMTheme.ink2)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            Task { await sessionStore.signOut() }
                        } label: {
                            Text("退出登录")
                        }
                        .buttonStyle(EMDangerButtonStyle())
                    }
                    .padding(EMTheme.padding)
                }
            }
        }
    }
}

#Preview {
    WorkspacePickerView().environmentObject(SessionStore())
}
