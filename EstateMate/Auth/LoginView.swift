//
//  LoginView.swift
//  EstateMate
//
//  Minimal (Japanese-inspired) login UI.
//

import SwiftUI
import Supabase

struct LoginView: View {
    @EnvironmentObject var sessionStore: SessionStore
    private let auth = AuthService()

    // 登录方式：仅 Google（Gmail）

    var body: some View {
        NavigationStack {
            EMScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("登录", subtitle: "使用 Gmail 登录")

                        EMCard {
                            if let msg = sessionStore.errorMessage {
                                Text(msg)
                                    .font(.callout)
                                    .foregroundStyle(.red)
                            }

                            Text("请使用你的 Gmail 授权登录。")
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink2)

                            Divider().overlay(EMTheme.line)
                                .padding(.vertical, 4)

                            Button {
                                Task { await signInOAuth(Provider.google) }
                            } label: {
                                Label("使用 Google 登录", systemImage: "g.circle")
                            }
                            .buttonStyle(EMSecondaryButtonStyle())
                            .disabled(sessionStore.isLoading)

                            Text("登录后将要求连接 Gmail，用于同步往来与自动发送邮件模版。")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.top, 6)
                        }
                    }
                    .padding(EMTheme.padding)
                }
                .overlay {
                    if sessionStore.isLoading {
                        ProgressView()
                            .padding(16)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private func signInOAuth(_ provider: Provider) async {
        sessionStore.isLoading = true
        defer { sessionStore.isLoading = false }
        do {
            let s = try await auth.signInWithOAuth(provider: provider)
            sessionStore.session = s
            sessionStore.errorMessage = nil
        } catch {
            sessionStore.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    LoginView().environmentObject(SessionStore())
}
