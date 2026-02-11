//
//  EmailTemplatePickerSheetView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

/// Picker sheet used when binding an email template to an OpenHouse event.
///
/// NOTE: UI intentionally matches `EmailTemplatesListView` (search + list + empty state),
/// but tap-to-select will dismiss and return the chosen template id.
struct EmailTemplatePickerSheetView: View {
    let templates: [EmailTemplateRecord]
    @Binding var selectedTemplateId: UUID?

    var defaultWorkspace: EstateMateWorkspaceKind = .openhouse

    @Environment(\.dismiss) private var dismiss

    @State private var localTemplates: [EmailTemplateRecord]
    @State private var query: String = ""

    @State private var isRefreshing: Bool = false
    @State private var errorMessage: String?

    init(
        templates: [EmailTemplateRecord],
        selectedTemplateId: Binding<UUID?>,
        defaultWorkspace: EstateMateWorkspaceKind = .openhouse
    ) {
        self.templates = templates
        self._selectedTemplateId = selectedTemplateId
        self.defaultWorkspace = defaultWorkspace
        self._localTemplates = State(initialValue: templates)
    }

    private var filtered: [EmailTemplateRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return localTemplates }

        return localTemplates.filter {
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

                    if filtered.isEmpty {
                        EMCard {
                            VStack(alignment: .center, spacing: 12) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(EMTheme.ink2)

                                Text("还没有任何邮件模版")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)

                                Text("先创建一份模版，然后回来这里下拉刷新再选择绑定。")
                                    .font(.footnote)
                                    .foregroundStyle(EMTheme.ink2)
                                    .multilineTextAlignment(.center)

                                NavigationLink {
                                    EmailTemplateEditView(mode: .create(workspace: defaultWorkspace))
                                } label: {
                                    Text("新建第一个模版")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                                .padding(.top, 4)

                                Button(isRefreshing ? "刷新中…" : "我已创建，刷新列表") {
                                    Task { await refreshTemplates() }
                                }
                                .buttonStyle(EMSecondaryButtonStyle())
                                .disabled(isRefreshing)
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
                                            Text(t.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（未命名模版）" : t.name)
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

                                    Text(t.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（无主题）" : t.subject)
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
                    EmailTemplateEditView(mode: .create(workspace: defaultWorkspace))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            // When opening the sheet, ensure the initial list is fresh enough.
            localTemplates = templates
        }
        .onTapGesture { hideKeyboard() }
    }

    private func refreshTemplates() async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            localTemplates = try await EmailTemplateService().listTemplates(workspace: nil)
        } catch {
            errorMessage = "刷新失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        EmailTemplatePickerSheetView(templates: [], selectedTemplateId: .constant(nil))
    }
}
