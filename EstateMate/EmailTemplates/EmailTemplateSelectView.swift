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

    @State private var query: String = ""
    @State private var templates: [EmailTemplateRecord] = []

    @State private var isLoading = false
    @State private var errorMessage: String?

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
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                Section {
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
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(EMTheme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }

                if !isLoading, filtered.isEmpty, errorMessage == nil {
                    Section {
                        Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无邮件模版" : "没有匹配的邮件模版")
                            .foregroundStyle(EMTheme.ink2)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section {
                            NavigationLink {
                                EmailTemplateEditView(mode: .create(workspace: workspace))
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(EMTheme.accent)
                                    Text("新建第一个模版")
                                        .foregroundStyle(EMTheme.ink)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                } else {
                    Section {
                        ForEach(filtered) { t in
                            Button {
                                selectedTemplateId = t.id
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(t.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（未命名模版）" : t.name)
                                            .font(.headline)
                                            .foregroundStyle(EMTheme.ink)

                                        Text(t.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（无主题）" : t.subject)
                                            .font(.subheadline)
                                            .foregroundStyle(EMTheme.ink2)
                                            .lineLimit(2)

                                        Text(t.workspace.title)
                                            .font(.caption)
                                            .foregroundStyle(EMTheme.ink2)
                                    }

                                    Spacer()

                                    if selectedTemplateId == t.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(EMTheme.accent)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("选择邮件模版")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索邮件模版")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") { dismiss() }
                        .foregroundStyle(EMTheme.ink2)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        EmailTemplateEditView(mode: .create(workspace: workspace))
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(EMTheme.accent)
                    }
                }
            }
            .task { await reload() }
            .refreshable { await reload() }
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
