//
//  EmailTemplatesListView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct EmailTemplatesListView: View {
    let workspace: EstateMateWorkspaceKind

    /// Optional selection mode (used when binding a template to an OpenHouse event).
    /// When provided, rows become tap-to-select and dismiss.
    var selection: Binding<UUID?>? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var templates: [EmailTemplateRecord] = []
    @State private var query: String = ""

    @State private var includeArchived: Bool = false
    @State private var isWorking: Bool = false

    @State private var isVariablesPresented = false
    @State private var selectedTemplateForVariables: EmailTemplateRecord?

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
                    EMSectionHeader("邮件模版", subtitle: "开放日 & 客户管理共用")

                    EMCard {
                        EMTextField(title: "搜索", text: $query, prompt: "按名称/主题/正文搜索")
                    }

                    EMCard {
                        Toggle("显示已归档", isOn: $includeArchived)
                            .font(.callout)
                            .tint(EMTheme.accent)
                            .padding(.vertical, 10)
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

                    if let selection {
                        EMCard {
                            Button {
                                selection.wrappedValue = nil
                                dismiss()
                            } label: {
                                HStack {
                                    Text("不绑定")
                                        .font(.headline)
                                        .foregroundStyle(EMTheme.ink)
                                    Spacer()
                                    if selection.wrappedValue == nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(EMTheme.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(filtered) { t in
                        if let selection {
                            Button {
                                selection.wrappedValue = t.id
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

                                            if selection.wrappedValue == t.id {
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
                        } else {
                            NavigationLink {
                                EmailTemplateEditView(mode: .edit(templateId: t.id, workspace: workspace))
                            } label: {
                                EMCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                                    Text(t.name.isEmpty ? "（未命名模版）" : t.name)
                                                        .font(.headline)
                                                        .foregroundStyle(EMTheme.ink)
                                                        .lineLimit(1)

                                                    if t.isArchived {
                                                        EMChip(text: "已归档", isOn: true)
                                                    }
                                                }

                                                Text(t.workspace.title)
                                                    .font(.caption)
                                                    .foregroundStyle(EMTheme.ink2)
                                            }

                                            Spacer()

                                            HStack(spacing: 8) {
                                                Text("变量：\(t.variables.count)")
                                                    .font(.footnote)
                                                    .foregroundStyle(EMTheme.ink2)

                                                Menu {
                                                    Button(t.isArchived ? "取消归档" : "归档") {
                                                        Task {
                                                            await archiveTemplate(t, isArchived: !t.isArchived)
                                                        }
                                                    }

                                                    Divider()

                                                    Button {
                                                        selectedTemplateForVariables = t
                                                        isVariablesPresented = true
                                                    } label: {
                                                        Text("管理变量")
                                                    }
                                                } label: {
                                                    Image(systemName: "ellipsis")
                                                        .font(.footnote.weight(.semibold))
                                                        .foregroundStyle(EMTheme.ink2)
                                                        .frame(width: 28, height: 28)
                                                        .background(Circle().fill(Color.white.opacity(0.7)))
                                                        .overlay(Circle().stroke(EMTheme.line, lineWidth: 1))
                                                }
                                                .buttonStyle(.plain)
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
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("邮件模版")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if selection != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") { dismiss() }
                        .foregroundStyle(EMTheme.ink2)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    EmailTemplateEditView(mode: .create(workspace: workspace))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        
        .sheet(isPresented: $isVariablesPresented, onDismiss: {
            selectedTemplateForVariables = nil
        }) {
            NavigationStack {
                if let selectedTemplateForVariables {
                    EmailTemplateVariablesEditView(
                        template: selectedTemplateForVariables,
                        onSaved: {
                            isVariablesPresented = false
                            Task { await reload() }
                        },
                        onCancel: {
                            isVariablesPresented = false
                        }
                    )
                }
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
        .onChange(of: includeArchived) { _, _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Shared templates across OpenHouse + CRM.
            templates = try await service.listTemplates(workspace: nil, includeArchived: includeArchived)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func archiveTemplate(_ template: EmailTemplateRecord, isArchived: Bool) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            _ = try await service.archiveTemplate(id: template.id, isArchived: isArchived)
            await reload()
        } catch {
            errorMessage = "操作失败：\(error.localizedDescription)"
        }
    }
}

private struct EmailTemplateVariablesEditView: View {
    let template: EmailTemplateRecord
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    @State private var variables: [EmailTemplateVariable]

    @State private var newKey: String = ""
    @State private var newKeyError: String?
    @State private var newLabel: String = ""

    private let service = EmailTemplateService()

    init(template: EmailTemplateRecord, onSaved: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.template = template
        self.onSaved = onSaved
        self.onCancel = onCancel
        _variables = State(initialValue: template.variables)
    }

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("变量", subtitle: template.name.isEmpty ? "（未命名模版）" : template.name)

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("已有变量")
                                .font(.headline)
                                .foregroundStyle(EMTheme.ink)

                            if variables.isEmpty {
                                Text("暂无变量")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                            }

                            ForEach(Array(variables.enumerated()), id: \.offset) { idx, v in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("{{\(v.key)}}")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(EMTheme.accent)
                                        Spacer()
                                        Button(role: .destructive) {
                                            variables.remove(at: idx)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.footnote.weight(.semibold))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Text(v.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : v.label)
                                        .font(.subheadline)
                                        .foregroundStyle(EMTheme.ink)

                                    if idx != variables.count - 1 {
                                        Divider().overlay(EMTheme.line)
                                    }
                                }
                            }
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("新增变量")
                                .font(.headline)
                                .foregroundStyle(EMTheme.ink)

                            EMTextField(title: "key", text: $newKey, prompt: "例如：client_name")
                                .onChange(of: newKey) { _, _ in
                                    newKeyError = nil
                                }

                            if let newKeyError {
                                Text(newKeyError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .padding(.top, -4)
                            }

                            Text("格式要求：仅支持 a-z / 0-9 / _，会自动转小写并移除其它字符")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.top, newKeyError == nil ? -4 : 0)

                            EMTextField(title: "要填写的内容", text: $newLabel, prompt: "例如：客户姓名 / 活动地址 / 经纪人姓名")

                            Button {
                                addVariable()
                            } label: {
                                Text("添加变量")
                            }
                            .buttonStyle(EMSecondaryButtonStyle())
                        }
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Text(isSaving ? "保存中…" : "保存")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isSaving))
                    .disabled(isSaving)

                    Button {
                        onCancel()
                    } label: {
                        Text("取消")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())
                    .disabled(isSaving)

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
            .safeAreaPadding(.top, 8)
        }
        .navigationTitle("变量")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addVariable() {
        let key = EmailTemplateRenderer.normalizeKey(newKey)
        guard !key.isEmpty else {
            newKeyError = "变量 key 不能为空（仅支持 a-z / 0-9 / _）"
            return
        }

        if variables.contains(where: { $0.key == key }) {
            newKeyError = "变量 key 重复：\(key)"
            return
        }

        let label = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        variables.append(.init(key: key, label: label))
        newKey = ""
        newKeyError = nil
        newLabel = ""
        errorMessage = nil
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            _ = try await service.updateTemplate(
                id: template.id,
                patch: EmailTemplateUpdate(
                    workspace: nil,
                    name: nil,
                    subject: nil,
                    body: nil,
                    variables: variables,
                    isArchived: nil
                )
            )
            onSaved()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}


#Preview {
    NavigationStack {
        EmailTemplatesListView(workspace: .crm)
    }
}
