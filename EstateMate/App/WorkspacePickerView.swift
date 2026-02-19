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
                GeometryReader { geo in
                    let rowCount = CGFloat(Workspace.allCases.count + 1)
                    let rowHeight: CGFloat = max(58, (geo.size.height - 220) / rowCount)

                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("选择系统", subtitle: "选择要进入的模块")

                        EMCard {
                            VStack(spacing: 0) {
                                ForEach(Array(Workspace.allCases.enumerated()), id: \.element) { idx, w in
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
                                        .frame(maxHeight: .infinity)
                                    }
                                    .frame(height: rowHeight)
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
                                    .frame(maxHeight: .infinity)
                                }
                                .frame(height: rowHeight)
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            Task { await sessionStore.signOut() }
                        } label: {
                            Text("退出登录")
                        }
                        .buttonStyle(EMDangerButtonStyle())

                        Spacer(minLength: 0)
                    }
                    .padding(EMTheme.padding)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }
}

#Preview {
    WorkspacePickerView().environmentObject(SessionStore())
}
