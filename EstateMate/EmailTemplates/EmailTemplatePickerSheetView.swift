//
//  EmailTemplatePickerSheetView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct EmailTemplatePickerSheetView: View {
    let templates: [EmailTemplateRecord]
    @Binding var selectedTemplateId: UUID?

    var defaultWorkspace: EstateMateWorkspaceKind = .openhouse

    @Environment(\.dismiss) private var dismiss

    @State private var localTemplates: [EmailTemplateRecord]
    @State private var isRefreshing: Bool = false

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

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("选择邮件模版", subtitle: "选择后会绑定到活动（可选）")

                    EMCard {
                        Button {
                            selectedTemplateId = nil
                            dismiss()
                        } label: {
                            HStack {
                                Text("不绑定")
                                    .foregroundStyle(EMTheme.ink)
                                Spacer()
                                if selectedTemplateId == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(EMTheme.accent)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }

                    if localTemplates.isEmpty {
                        EMCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("暂无邮件模版")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)

                                Text("你可以先新增邮件模版，然后回到这里刷新列表再选择绑定。")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)

                                NavigationLink {
                                    EmailTemplateEditView(mode: .create(workspace: defaultWorkspace))
                                } label: {
                                    Text("新增邮件模版")
                                }
                                .buttonStyle(EMPrimaryButtonStyle(disabled: false))

                                Button(isRefreshing ? "刷新中..." : "我已创建，刷新列表") {
                                    Task { await refreshTemplates() }
                                }
                                .buttonStyle(EMSecondaryButtonStyle())
                                .disabled(isRefreshing)
                            }
                        }
                    }

                    ForEach(localTemplates) { t in
                        Button {
                            selectedTemplateId = t.id
                            dismiss()
                        } label: {
                            EMCard {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(t.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（未命名模版）" : t.name)
                                            .font(.headline)
                                            .foregroundStyle(EMTheme.ink)
                                            .lineLimit(1)

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
                                    }
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
        .onTapGesture { hideKeyboard() }
    }

    private func refreshTemplates() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            localTemplates = try await EmailTemplateService().listTemplates(workspace: nil)
        } catch {
            // keep silent; empty state already guides user
        }
    }
}

#Preview {
    NavigationStack {
        EmailTemplatePickerSheetView(templates: [], selectedTemplateId: .constant(nil))
    }
}
