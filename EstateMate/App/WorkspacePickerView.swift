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
                    let iconBox: CGFloat = min(46, max(32, rowHeight * 0.55))
                    let iconFontSize: CGFloat = min(22, max(16, iconBox * 0.5))
                    let titleFontSize: CGFloat = min(20, max(17, rowHeight * 0.30))
                    let subtitleFontSize: CGFloat = min(14, max(12, rowHeight * 0.20))

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
                                                .font(.system(size: iconFontSize, weight: .semibold))
                                                .foregroundStyle(EMTheme.accent)
                                                .frame(width: iconBox, height: iconBox)
                                                .background(EMTheme.accent.opacity(0.12))
                                                .clipShape(RoundedRectangle(cornerRadius: max(8, iconBox * 0.28), style: .continuous))

                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(w.title)
                                                    .font(.system(size: titleFontSize, weight: .semibold))
                                                Text(w.subtitle)
                                                    .font(.system(size: subtitleFontSize))
                                                    .foregroundStyle(EMTheme.ink2)
                                                    .lineLimit(2)
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
                                            .font(.system(size: iconFontSize, weight: .semibold))
                                            .foregroundStyle(EMTheme.accent)
                                            .frame(width: iconBox, height: iconBox)
                                            .background(EMTheme.accent.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: max(8, iconBox * 0.28), style: .continuous))

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("邮箱绑定")
                                                .font(.system(size: titleFontSize, weight: .semibold))
                                            Text("连接 Gmail，用于自动发送与同步邮件往来")
                                                .font(.system(size: subtitleFontSize))
                                                .foregroundStyle(EMTheme.ink2)
                                                .lineLimit(2)
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
