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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                EMSectionHeader("活动策划", subtitle: "创建表单、创建活动、开始现场填写")

                EMCard {
                    NavigationLink {
                        OpenHouseEventHubView(initialTab: .create)
                    } label: {
                        row(icon: "plus.app", title: "新建活动", subtitle: "创建活动并绑定表单")
                    }

                    Divider().overlay(EMTheme.line)

                    NavigationLink {
                        OpenHouseEventHubView(initialTab: .list)
                    } label: {
                        row(icon: "list.bullet.rectangle", title: "活动列表", subtitle: "查看并启用活动")
                    }

                    Divider().overlay(EMTheme.line)

                    NavigationLink {
                        OpenHouseFormsView()
                    } label: {
                        row(icon: "doc.text", title: "表单管理", subtitle: "查看与管理已创建的表单")
                    }

                    Divider().overlay(EMTheme.line)

                    NavigationLink {
                        EmailTemplatesListView(workspace: .openhouse)
                    } label: {
                        row(icon: "envelope.open", title: "邮件模版", subtitle: "查看与管理邮件模版（提交后自动发信会用到）")
                    }

                    Divider().overlay(EMTheme.line)

                    NavigationLink {
                        OpenHouseVisitorListView()
                    } label: {
                        row(icon: "person.3", title: "访客列表", subtitle: "按活动查看所有访客登记")
                    }
                }

                NavigationLink {
                    OpenHouseStartActivityView()
                } label: {
                    Text("准备开始活动")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EMPrimaryButtonStyle(disabled: false))

                Button {
                    sessionStore.selectedWorkspace = nil
                } label: {
                    Text("返回选择系统")
                }
                .buttonStyle(EMSecondaryButtonStyle())
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
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
    OpenHouseHomeView().environmentObject(SessionStore())
}
