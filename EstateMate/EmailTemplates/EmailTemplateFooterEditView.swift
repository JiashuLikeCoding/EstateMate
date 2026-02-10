//
//  EmailTemplateFooterEditView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct EmailTemplateFooterEditView: View {
    let workspace: EstateMateWorkspaceKind

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var footerHTML: String = ""
    @State private var footerText: String = ""

    private let service = EmailTemplateSettingsService()

    var body: some View {
        EMScreen("统一邮件结尾") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("统一结尾（\(workspace.title)）", subtitle: "发送邮件时会自动追加到正文末尾")

                    if let errorMessage {
                        EMCard { Text(errorMessage).font(.subheadline).foregroundStyle(.red) }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("HTML 结尾（推荐）")
                                .font(.headline)
                                .foregroundStyle(EMTheme.ink)

                            Text("支持 <b>加粗</b>、<span style=\"color:#...\">颜色</span>、字号等。")
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink2)

                            TextEditor(text: $footerHTML)
                                .frame(minHeight: 160)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.65))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(EMTheme.line, lineWidth: 1))
                                )
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("纯文本结尾（兜底）")
                                .font(.headline)
                                .foregroundStyle(EMTheme.ink)

                            Text("当 HTML 为空时，会使用这段纯文本追加。")
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink2)

                            TextEditor(text: $footerText)
                                .frame(minHeight: 120)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.65))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(EMTheme.line, lineWidth: 1))
                                )
                        }
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Text(isLoading ? "保存中…" : "保存")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading))
                    .disabled(isLoading)

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .task {
            await load()
        }
        .onTapGesture { hideKeyboard() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let s = try await service.getSettings(workspace: workspace) {
                footerHTML = s.footerHTML
                footerText = s.footerText
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        hideKeyboard()
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await service.upsertSettings(
                .init(
                    workspace: workspace,
                    footerHTML: footerHTML,
                    footerText: footerText
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        EmailTemplateFooterEditView(workspace: .openhouse)
    }
}
