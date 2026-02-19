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
                GeometryReader { geo in
                    let rowCount: CGFloat = 3
                    let rowHeight: CGFloat = max(58, (geo.size.height - 220) / rowCount)
                    let iconBox: CGFloat = min(46, max(32, rowHeight * 0.55))
                    let iconFontSize: CGFloat = min(22, max(16, iconBox * 0.5))
                    let titleFontSize: CGFloat = min(20, max(17, rowHeight * 0.30))
                    let subtitleFontSize: CGFloat = min(14, max(12, rowHeight * 0.20))

                    let accent = Color.blue

                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("客户管理", subtitle: "线索、客户、任务（开发中）")

                        hero(icon: "person.2", title: "客户管理", subtitle: "客户资料 · 邮件记录 · 待办任务", accent: accent)

                        EMCard {
                            VStack(spacing: 0) {
                                NavigationLink {
                                    CRMContactsListView()
                                } label: {
                                    row(icon: "person.2", title: "客户列表", subtitle: "查看与搜索客户", accent: accent, iconBox: iconBox, iconFontSize: iconFontSize, titleFontSize: titleFontSize, subtitleFontSize: subtitleFontSize)
                                        .frame(height: rowHeight)
                                }
                                .buttonStyle(.plain)

                                Divider().overlay(EMTheme.line)

                                NavigationLink {
                                    CRMContactEditView(mode: .create)
                                } label: {
                                    row(icon: "person.badge.plus", title: "新增客户", subtitle: "快速录入一位客户", accent: accent, iconBox: iconBox, iconFontSize: iconFontSize, titleFontSize: titleFontSize, subtitleFontSize: subtitleFontSize)
                                        .frame(height: rowHeight)
                                }
                                .buttonStyle(.plain)

                                Divider().overlay(EMTheme.line)

                                NavigationLink {
                                    CRMTasksListView()
                                } label: {
                                    row(icon: "checklist", title: "待办任务", subtitle: "跟进提醒与记录", accent: accent, iconBox: iconBox, iconFontSize: iconFontSize, titleFontSize: titleFontSize, subtitleFontSize: subtitleFontSize)
                                        .frame(height: rowHeight)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            sessionStore.selectedWorkspace = nil
                        } label: {
                            Text("返回选择系统")
                        }
                        .buttonStyle(EMSecondaryButtonStyle())
                        .tint(accent)

                        Spacer(minLength: 0)
                    }
                    .padding(EMTheme.padding)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }

    private func row(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color,
        iconBox: CGFloat,
        iconFontSize: CGFloat,
        titleFontSize: CGFloat,
        subtitleFontSize: CGFloat
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: iconFontSize, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: iconBox, height: iconBox)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: max(8, iconBox * 0.28), style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: titleFontSize, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: subtitleFontSize))
                    .foregroundStyle(EMTheme.ink2)
                    .lineLimit(2)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .frame(maxHeight: .infinity)
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
    RootView().environmentObject(SessionStore())
}
