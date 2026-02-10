//
//  EmailTemplatesListView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct EmailTemplatesListView: View {
    let workspace: EstateMateWorkspaceKind

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var templates: [EmailTemplateRecord] = []
    @State private var query: String = ""

    @State private var isCreatePresented = false

    private let service = EmailTemplateService()

    var filtered: [EmailTemplateRecord] {
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
                    EMSectionHeader("邮件模版", subtitle: "\(workspace.title) · 支持变量：{{key}}")

                    EMCard {
                        EMTextField(title: "搜索", text: $query, prompt: "按名称/主题/正文搜索")
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
                            VStack(alignment: .leading, spacing: 6) {
                                Text("暂无模版")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)
                                Text("点右上角“新增”创建第一份邮件模版")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                            }
                        }
                    }

                    ForEach(filtered) { t in
                        NavigationLink {
                            EmailTemplateEditView(mode: .edit(templateId: t.id, workspace: workspace))
                        } label: {
                            EMCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(t.name.isEmpty ? "（未命名模版）" : t.name)
                                            .font(.headline)
                                            .foregroundStyle(EMTheme.ink)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("变量：\(t.variables.count)")
                                            .font(.footnote)
                                            .foregroundStyle(EMTheme.ink2)
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

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("邮件模版")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("新增") { isCreatePresented = true }
            }
        }
        .sheet(isPresented: $isCreatePresented, onDismiss: {
            Task { await reload() }
        }) {
            NavigationStack {
                EmailTemplateEditView(mode: .create(workspace: workspace))
            }
        }
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
        .onAppear {
            // When returning from edit view (NavigationLink), refresh list.
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
            templates = try await service.listTemplates(workspace: workspace)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        EmailTemplatesListView(workspace: .crm)
    }
}
