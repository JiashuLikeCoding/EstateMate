//
//  OpenHouseHomeView.swift
//  EstateMate
//

import SwiftUI

struct OpenHouseHomeView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            EMScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("开放日", subtitle: "创建表单、创建活动、开启访客填写模式")

                        EMCard {
                            Text("活动")
                                .font(.headline)

                            NavigationLink {
                                OpenHouseEventHubView(initialTab: .create)
                            } label: {
                                row(title: "新建活动", subtitle: "创建活动并绑定表单")
                            }

                            Divider().overlay(EMTheme.line)

                            NavigationLink {
                                OpenHouseEventHubView(initialTab: .list)
                            } label: {
                                row(title: "活动列表", subtitle: "查看并启用活动")
                            }
                        }

                        EMCard {
                            Text("表单")
                                .font(.headline)

                            NavigationLink {
                                OpenHouseFormsView()
                            } label: {
                                row(title: "表单管理", subtitle: "查看与管理已创建的表单")
                            }

                            Divider().overlay(EMTheme.line)

                            NavigationLink {
                                FormBuilderAdaptiveView()
                            } label: {
                                row(title: "表单设计", subtitle: "创建新表单")
                            }
                        }

                        EMCard {
                            Text("现场")
                                .font(.headline)

                            NavigationLink {
                                OpenHouseGuestModeV2View()
                            } label: {
                                row(title: "访客模式", subtitle: "现场给客人填写，提交后自动清空")
                            }
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

    private func row(title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
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
}

#Preview {
    OpenHouseHomeView().environmentObject(SessionStore())
}
