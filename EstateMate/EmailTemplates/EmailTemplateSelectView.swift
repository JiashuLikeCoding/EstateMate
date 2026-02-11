//
//  EmailTemplateSelectView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-11.
//

import SwiftUI

/// Selection UI for binding an email template to another object (e.g. OpenHouse Event).
///
/// This intentionally reuses the same visual language as `EmailTemplatesListView`,
/// but changes row interaction to "tap to select & dismiss".
struct EmailTemplateSelectView: View {
    let workspace: EstateMateWorkspaceKind
    @Binding var selectedTemplateId: UUID?

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var templates: [EmailTemplateRecord] = []
    @State private var query: String = ""

    private let service = EmailTemplateService()

    private var filtered: [EmailTemplateRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return templates }

        return templates.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
                $0.subject.localizedCaseInsensitiveContains(q) ||
                $0.body.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("邮件模版", subtitle: "选择后会绑定到活动（可选）")

                    EMCard {
                        EMTextField(title: "搜索", text: $query, prompt: "按名称/主题/正文搜索")
                    }

                    EMCard {
                        Button {
                            selectedTemplateId = nil
                            dismiss()
                        } label: {
                            HStack {
                                Text("不绑定")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)

                                Spacer()

                                if selectedTemplateId == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(EMTheme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    if isLoading {
                        EMCard {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("正在加载…")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    if !isLoading, filtered.isEmpty, errorMessage == nil {
                        EMCard {
                            VStack(alignment: .center, spacing: 12) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(EMTheme.ink2)

                                Text("还没有任何邮件模版")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)

                                Text("创建一份模版后，就可以在开放日自动发信、或在客户管理里快速发送。")
                                    .font(.footnote)
                                    .foregroundStyle(EMTheme.ink2)
                                    .multilineTextAlignment(.center)

                                NavigationLink {
                                    EmailTemplateEditView(mode: .create(workspace: workspace))
                                } label: {
                                    Text("新建第一个模版")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                        }
                    }

                    ForEach(filtered) { t in
                        Button {
                            selectedTemplateId = t.id
                            dismiss()
                        } label: {
                            EMCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(t.name.isEmpty ? "（未命名模版）" : t.name)
                                                .font(.headline)
                                                .foregroundStyle(EMTheme.ink)
                                                .lineLimit(1)

                                            Text(t.workspace.title)
                                                .font(.caption)
                                                .foregroundStyle(EMTheme.ink2)
                                        }

                                        Spacer()

                                        if selectedTemplateId == t.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(EMTheme.accent)
                                        }
                                    }

                                    Text(t.subject.isEmpty ? "（无主题）" : t.subject)
                                        .font(.subheadline)
                                        .foregroundStyle(EMTheme.ink2)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("取消")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("邮件模版")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    EmailTemplateEditView(mode: .create(workspace: workspace))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .onAppear {
            Task { await reload() }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            templates = try await service.listTemplates(workspace: nil)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        EmailTemplateSelectView(workspace: .openhouse, selectedTemplateId: .constant(nil))
    }
}
