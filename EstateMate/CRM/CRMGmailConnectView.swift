//
//  CRMGmailConnectView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMGmailConnectView: View {
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    @State private var connectedEmail: String?

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("Gmail 同步", subtitle: "连接你的 Gmail，用于自动发送与同步邮件往来")

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("连接状态")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)
                                Spacer()
                                if let connectedEmail {
                                    Text("已连接")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.green)
                                } else {
                                    Text("未连接")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(EMTheme.ink2)
                                }
                            }

                            if let connectedEmail {
                                Text(connectedEmail)
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                            } else {
                                Text("连接后：开放日提交可自动发送邮件模版，并在客户详情里同步 Gmail 往来。")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                            }

                            Divider().overlay(EMTheme.line)

                            Button(isLoading ? "处理中…" : "连接 Gmail") {
                                Task { await connect() }
                            }
                            .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading))
                            .disabled(isLoading)

                            Button(isLoading ? "处理中…" : "刷新状态") {
                                Task { await loadStatus() }
                            }
                            .buttonStyle(EMSecondaryButtonStyle())
                            .disabled(isLoading)

                            if connectedEmail != nil {
                                Button("断开连接") {
                                    Task { await disconnect() }
                                }
                                .buttonStyle(EMDangerButtonStyle())
                                .disabled(isLoading)
                            }
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("说明")
                                .font(.headline)
                                .foregroundStyle(EMTheme.ink)
                            Text("• 第一次连接会弹出 Google 授权页面（Internal 测试账号可用）。\n• 如需同步历史往来，我们会先同步最近一段时间（后续可调）。")
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("Gmail")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStatus() }
        .onTapGesture { hideKeyboard() }
    }

    private func loadStatus() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let status = try await CRMGmailIntegrationService().status()
            connectedEmail = status.email
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func connect() async {
        hideKeyboard()
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let status = try await CRMGmailIntegrationService().connectInteractive()
            connectedEmail = status.email
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func disconnect() async {
        hideKeyboard()
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            try await CRMGmailIntegrationService().disconnect()
            connectedEmail = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        CRMGmailConnectView()
    }
}
