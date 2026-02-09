//
//  RegisterView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    private let auth = AuthService()

    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""

    private var canSubmit: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !e.isEmpty && !password.isEmpty && password == confirm
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("创建账号")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                            Text("用邮箱注册，后续可绑定 Apple / Google / 手机号")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.72))
                        }

                        AuthCard {
                            if let msg = sessionStore.errorMessage {
                                Text(msg)
                                    .font(.callout)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            AuthTextField(title: "邮箱", text: $email, keyboard: .emailAddress)
                            AuthTextField(title: "密码", text: $password, isSecure: true)
                            AuthTextField(title: "确认密码", text: $confirm, isSecure: true)

                            Button {
                                Task { await signUp() }
                            } label: {
                                Text("注册")
                            }
                            .buttonStyle(PrimaryButtonStyle(isDisabled: !canSubmit || sessionStore.isLoading))
                            .disabled(!canSubmit || sessionStore.isLoading)

                            Button {
                                dismiss()
                            } label: {
                                Text("已有账号？返回登录")
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.top, 4)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                }

                LoadingOverlay(isPresented: sessionStore.isLoading)
            }
            .navigationBarHidden(true)
        }
    }

    private func signUp() async {
        sessionStore.isLoading = true
        defer { sessionStore.isLoading = false }
        do {
            guard password == confirm else {
                sessionStore.errorMessage = "两次密码不一致"
                return
            }
            try await auth.signUpEmail(email: email, password: password)
            sessionStore.errorMessage = nil
            dismiss()
        } catch {
            sessionStore.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RegisterView().environmentObject(SessionStore())
}
