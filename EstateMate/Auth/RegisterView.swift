//
//  RegisterView.swift
//  EstateMate
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
            EMScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("注册", subtitle: "使用邮箱创建账号")

                        EMCard {
                            if let msg = sessionStore.errorMessage {
                                Text(msg)
                                    .font(.callout)
                                    .foregroundStyle(.red)
                            }

                            EMTextField(title: "邮箱", text: $email, keyboard: .emailAddress)
                            EMTextField(title: "密码", text: $password, isSecure: true)
                            EMTextField(title: "确认密码", text: $confirm, isSecure: true)

                            Button {
                                Task { await signUp() }
                            } label: {
                                Text("创建账号")
                            }
                            .buttonStyle(EMPrimaryButtonStyle(disabled: !canSubmit || sessionStore.isLoading))
                            .disabled(!canSubmit || sessionStore.isLoading)

                            Button {
                                dismiss()
                            } label: {
                                Text("返回登录")
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
            }
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
