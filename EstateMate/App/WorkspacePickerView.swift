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
                    let rowHeight: CGFloat = min(90, max(56, (geo.size.height - 320) / rowCount))
                    let iconBox: CGFloat = min(42, max(28, rowHeight * 0.52))
                    let iconFontSize: CGFloat = min(20, max(15, iconBox * 0.50))
                    let titleFontSize: CGFloat = min(19, max(16, rowHeight * 0.30))
                    let subtitleFontSize: CGFloat = min(13, max(11.5, rowHeight * 0.20))

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
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(EMTheme.ink2)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(accent.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    WorkspacePickerView().environmentObject(SessionStore())
}
