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
                    let rowHeight: CGFloat = min(90, max(56, (geo.size.height - 320) / rowCount))
                    let iconBox: CGFloat = min(42, max(28, rowHeight * 0.52))
                    let iconFontSize: CGFloat = min(20, max(15, iconBox * 0.50))
                    let titleFontSize: CGFloat = min(19, max(16, rowHeight * 0.30))
                    let subtitleFontSize: CGFloat = min(13, max(11.5, rowHeight * 0.20))

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
    RootView().environmentObject(SessionStore())
}
