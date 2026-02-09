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

    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            EMScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("登录", subtitle: "使用邮箱或 Google 登录")

                        EMCard {
                            if let msg = sessionStore.errorMessage {
                                Text(msg)
                                    .font(.callout)
                                    .foregroundStyle(.red)
                            }

                            EMTextField(title: "邮箱", text: $email, keyboard: .emailAddress)
                            EMTextField(title: "密码", text: $password, isSecure: true)

                            Button {
                                Task { await signInEmail() }
                            } label: {
                                Text("登录")
                            }
                            .buttonStyle(EMPrimaryButtonStyle(disabled: !canSubmit || sessionStore.isLoading))
                            .disabled(!canSubmit || sessionStore.isLoading)

                            Text("或者")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 6)

                            Button {
                                Task { await signInOAuth(Provider.google) }
                            } label: {
                                Label("使用 Google 登录", systemImage: "g.circle")
                            }
                            .buttonStyle(EMSecondaryButtonStyle())
                            .disabled(sessionStore.isLoading)

                            Button {
                                showRegister = true
                            } label: {
                                Text("没有账号？注册")
                                    .font(.footnote.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
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
            .sheet(isPresented: $showRegister) {
                RegisterView().environmentObject(sessionStore)
            }
        }
    }

    private func signInEmail() async {
        sessionStore.isLoading = true
        defer { sessionStore.isLoading = false }
        do {
            let s = try await auth.signInEmail(email: email, password: password)
            sessionStore.session = s
            sessionStore.errorMessage = nil
        } catch {
            sessionStore.errorMessage = error.localizedDescription
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
