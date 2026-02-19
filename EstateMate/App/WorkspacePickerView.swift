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

                    let accent = Color.purple

                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("选择系统", subtitle: "选择要进入的模块")

                        hero(icon: "square.grid.2x2", title: "选择系统", subtitle: "快速切换：活动策划 / 客户管理 / 邮箱绑定", accent: accent)

                        EMCard {
                            VStack(spacing: 0) {
                                ForEach(Array(Workspace.allCases.enumerated()), id: \.element) { idx, w in
                                    Button {
                                        sessionStore.selectedWorkspace = w
                                    } label: {
                                        HStack(alignment: .center, spacing: 12) {
                                            Image(systemName: w.iconSystemName)
                                                .font(.system(size: iconFontSize, weight: .semibold))
                                                .foregroundStyle(accent)
                                                .frame(width: iconBox, height: iconBox)
                                                .background(accent.opacity(0.12))
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
                                            .foregroundStyle(accent)
                                            .frame(width: iconBox, height: iconBox)
                                            .background(accent.opacity(0.12))
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
                                            .foregroundStyle(accent.opacity(0.6))
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


    private func hero(icon: String, title: String, subtitle: String, accent: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(EMTheme.ink2)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(accent.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    WorkspacePickerView().environmentObject(SessionStore())
}
