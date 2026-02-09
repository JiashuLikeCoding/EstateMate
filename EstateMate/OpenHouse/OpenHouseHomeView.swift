//
//  OpenHouseHomeView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import SwiftUI

struct OpenHouseHomeView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("开放日")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                            Text("创建表单、创建活动、开启访客填写模式")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.72))
                        }

                        AuthCard {
                            NavigationLink {
                                OpenHouseEventsV2View()
                            } label: {
                                row(title: "活动管理", subtitle: "创建活动并绑定表单")
                            }

                            Divider().overlay(Color.white.opacity(0.12))

                            NavigationLink {
                                FormBuilderView()
                            } label: {
                                row(title: "表单设计", subtitle: "自定义字段（文本/电话/邮箱/单选）")
                            }

                            Divider().overlay(Color.white.opacity(0.12))

                            NavigationLink {
                                OpenHouseGuestModeV2View()
                            } label: {
                                row(title: "访客模式", subtitle: "现场给客人填写，提交后自动清空")
                            }
                        }

                        AuthCard {
                            Button {
                                Task { await sessionStore.signOut() }
                            } label: {
                                Text("退出登录")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func row(title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}

#Preview {
    OpenHouseHomeView().environmentObject(SessionStore())
}

#Preview {
    OpenHouseHomeView().environmentObject(SessionStore())
}
