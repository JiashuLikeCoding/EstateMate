//
//  OpenHouseHomeView.swift
//  EstateMate
//

import SwiftUI

/// OpenHouse home entry.
///
/// Note: Device lock is currently disabled. Multiple devices can use OpenHouse concurrently.
struct OpenHouseHomeView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            EMScreen {
                content
                    .padding(EMTheme.padding)
            }
        }
    }

    private var content: some View {
        GeometryReader { geo in
            let rowCount: CGFloat = 5
            let rowHeight: CGFloat = min(82, max(54, (geo.size.height - 320) / rowCount))
            let iconBox: CGFloat = min(40, max(28, rowHeight * 0.52))
            let iconFontSize: CGFloat = min(20, max(15, iconBox * 0.50))
            let titleFontSize: CGFloat = min(19, max(16, rowHeight * 0.28))
            let subtitleFontSize: CGFloat = min(13, max(11.5, rowHeight * 0.20))

            let accent = Color.green

            VStack(alignment: .leading, spacing: 18) {
                EMSectionHeader("活动策划", subtitle: "创建表单、创建活动、开始现场填写")

                hero(icon: "calendar.badge.clock", title: "活动策划", subtitle: "现场接待 · 访客登记 · 自动发信", accent: accent)

                EMCard {
                    VStack(spacing: 0) {
                        NavigationLink {
                            OpenHouseEventHubView(initialTab: .create)
                        } label: {
                            row(icon: "plus.app", title: "新建活动", subtitle: "创建活动并绑定表单", accent: accent, iconBox: iconBox, iconFontSize: iconFontSize, titleFontSize: titleFontSize, subtitleFontSize: subtitleFontSize)
                                .frame(height: rowHeight)
                        }

                        Divider().overlay(EMTheme.line)

                        NavigationLink {
                            OpenHouseEventHubView(initialTab: .list)
                        } label: {
                            row(icon: "list.bullet.rectangle", title: "活动列表", subtitle: "查看并启用活动", accent: accent, iconBox: iconBox, iconFontSize: iconFontSize, titleFontSize: titleFontSize, subtitleFontSize: subtitleFontSize)
                                .frame(height: rowHeight)
                        }

                        Divider().overlay(EMTheme.line)

                        NavigationLink {
                            OpenHouseFormsView()
                        } label: {
                            row(icon: "doc.text", title: "表单管理", subtitle: "查看与管理已创建的表单", accent: accent, iconBox: iconBox, iconFontSize: iconFontSize, titleFontSize: titleFontSize, subtitleFontSize: subtitleFontSize)
                                .frame(height: rowHeight)
                        }

                        Divider().overlay(EMTheme.line)

                        NavigationLink {
                            EmailTemplatesListView(workspace: .openhouse)
                        } label: {
                            row(icon: "envelope.open", title: "邮件模版", subtitle: "查看与管理邮件模版（提交后自动发信会用到）", accent: accent, iconBox: iconBox, iconFontSize: iconFontSize, titleFontSize: titleFontSize, subtitleFontSize: subtitleFontSize)
                                .frame(height: rowHeight)
                        }

                        Divider().overlay(EMTheme.line)

                        NavigationLink {
                            OpenHouseVisitorListView()
                        } label: {
                            row(icon: "person.3", title: "访客列表", subtitle: "按活动查看所有访客登记", accent: accent, iconBox: iconBox, iconFontSize: iconFontSize, titleFontSize: titleFontSize, subtitleFontSize: subtitleFontSize)
                                .frame(height: rowHeight)
                        }
                    }
                }

                NavigationLink {
                    OpenHouseStartActivityView()
                } label: {
                    Text("准备开始活动")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                .tint(accent)

                Button {
                    sessionStore.selectedWorkspace = nil
                } label: {
                    Text("返回选择系统")
                }
                .buttonStyle(EMSecondaryButtonStyle())
                .tint(accent)

                Spacer(minLength: 0)
            }
            .frame(minHeight: geo.size.height)
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
    OpenHouseHomeView().environmentObject(SessionStore())
}
