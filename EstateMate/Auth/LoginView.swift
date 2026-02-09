//
//  LoginView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
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
            ZStack {
                AuthBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        AuthCard {
                            if let msg = sessionStore.errorMessage {
                                Text(msg)
                                    .font(.callout)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            AuthTextField(title: "邮箱", text: $email, keyboard: .emailAddress)
                            AuthTextField(title: "密码", text: $password, isSecure: true)

                            Button {
                                Task { await signInEmail() }
                            } label: {
                                Text("登录")
                            }
                            .buttonStyle(PrimaryButtonStyle(isDisabled: !canSubmit || sessionStore.isLoading))
                            .disabled(!canSubmit || sessionStore.isLoading)

                            Divider().overlay(Color.white.opacity(0.12))

                            VStack(spacing: 10) {
                                Text("或者")
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.65))
                                    .frame(maxWidth: .infinity)

                                Button {
                                    Task { await signInOAuth(Provider.google) }
                                } label: {
                                    Label("使用 Google 登录", systemImage: "g.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .disabled(sessionStore.isLoading)
                            }

                            Button {
                                showRegister = true
                            } label: {
                                Text("没有账号？注册")
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.top, 4)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.white.opacity(0.85))

                            Button {
                                // TODO: wire to supabase reset password
                            } label: {
                                Text("忘记密码")
                                    .font(.footnote)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.white.opacity(0.70))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                }

                LoadingOverlay(isPresented: sessionStore.isLoading)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showRegister) {
                RegisterView().environmentObject(sessionStore)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EstateMate")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("专业的房产管理助手")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
