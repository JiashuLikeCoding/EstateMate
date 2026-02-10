//
//  EmailTemplateEditView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct EmailTemplateEditView: View {
    enum Mode: Equatable {
        case create(workspace: EstateMateWorkspaceKind)
        case edit(templateId: UUID, workspace: EstateMateWorkspaceKind)

        var title: String {
            switch self {
            case .create: return "新增邮件模版"
            case .edit: return "编辑邮件模版"
            }
        }

        var workspace: EstateMateWorkspaceKind {
            switch self {
            case let .create(workspace): return workspace
            case let .edit(_, workspace): return workspace
            }
        }

        var templateId: UUID? {
            switch self {
            case .create: return nil
            case let .edit(id, _): return id
            }
        }
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var name: String = ""
    @State private var subject: String = ""
    @State private var bodyText: String = ""

    @State private var variables: [EmailTemplateVariable] = []

    @State private var newVarKey: String = ""
    @State private var newVarLabel: String = ""
    @State private var newVarExample: String = ""

    private let service = EmailTemplateService()

    var renderedSubject: String {
        EmailTemplateRenderer.render(subject, variables: variables)
    }

    var renderedBody: String {
        EmailTemplateRenderer.render(bodyText, variables: variables)
    }

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(mode.title, subtitle: "在正文/主题中使用 {{key}} 插入变量")

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    EMCard {
                        EMTextField(title: "名称", text: $name, prompt: "例如：感谢来访（开放日）")
                        EMTextField(title: "主题", text: $subject, prompt: "例如：很高兴在开放日见到您，{{client_name}}")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("正文")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            TextEditor(text: $bodyText)
                                .frame(minHeight: 180)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.65))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(EMTheme.line, lineWidth: 1)
                                        )
                                )

                            if !variables.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(variables) { v in
                                            Button {
                                                insertVariableToken(v.key)
                                            } label: {
                                                Text("+ {{\(v.key)}}")
                                                    .font(.footnote.weight(.medium))
                                                    .foregroundStyle(EMTheme.accent)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule().fill(EMTheme.accent.opacity(0.10))
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("变量")
                                .font(.headline)
                                .foregroundStyle(EMTheme.ink)

                            if variables.isEmpty {
                                Text("暂无变量。你可以先创建变量，再在正文中插入 {{key}}")
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
                                    Text(v.label.isEmpty ? "（未命名变量）" : v.label)
                                        .font(.subheadline)
                                        .foregroundStyle(EMTheme.ink)
                                    if !v.example.isEmpty {
                                        Text("示例：\(v.example)")
                                            .font(.footnote)
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                    if idx != variables.count - 1 {
                                        Divider().overlay(EMTheme.line)
                                    }
                                }
                            }

                            Divider().overlay(EMTheme.line)

                            Text("新增变量")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(EMTheme.ink)

                            EMTextField(title: "key", text: $newVarKey, prompt: "例如：client_name")

                            Text("格式要求：仅支持 a-z / 0-9 / _，会自动转小写并移除其它字符")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.top, -4)
                            EMTextField(title: "显示名", text: $newVarLabel, prompt: "例如：客户姓名")
                            EMTextField(title: "示例值", text: $newVarExample, prompt: "例如：张三")

                            Button {
                                addVariable()
                            } label: {
                                Text("添加变量")
                            }
                            .buttonStyle(EMSecondaryButtonStyle())
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("预览")
                                .font(.headline)
                                .foregroundStyle(EMTheme.ink)

                            Text("主题预览")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            Text(renderedSubject.isEmpty ? "—" : renderedSubject)
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink)

                            Divider().overlay(EMTheme.line)

                            Text("正文预览")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            Text(renderedBody.isEmpty ? "—" : renderedBody)
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Text(isLoading ? "保存中…" : "保存")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading))
                    .disabled(isLoading)

                    if mode.templateId != nil {
                        Button(role: .destructive) {
                            Task { await archive() }
                        } label: {
                            Text("隐藏/归档")
                        }
                        .buttonStyle(EMSecondaryButtonStyle())
                        .disabled(isLoading)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("取消")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())
                    .disabled(isLoading)

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: mode) {
            await loadIfNeeded()
        }
        .onTapGesture {
            hideKeyboard()
        }
    }

    private func loadIfNeeded() async {
        guard let id = mode.templateId else {
            // create defaults
            variables = [EmailTemplateVariable.sample]
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // MVP: list+find by workspace; small dataset.
            let all = try await service.listTemplates(workspace: mode.workspace, includeArchived: true)
            if let t = all.first(where: { $0.id == id }) {
                name = t.name
                subject = t.subject
                bodyText = t.body
                variables = t.variables
            }
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func addVariable() {
        let key = EmailTemplateRenderer.normalizeKey(newVarKey)
        guard !key.isEmpty else {
            errorMessage = "变量 key 不能为空（仅支持 a-z / 0-9 / _）"
            return
        }

        if variables.contains(where: { $0.key == key }) {
            errorMessage = "变量 key 重复：\(key)"
            return
        }

        let label = newVarLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let example = newVarExample.trimmingCharacters(in: .whitespacesAndNewlines)

        variables.append(.init(key: key, label: label, example: example))
        newVarKey = ""
        newVarLabel = ""
        newVarExample = ""
        errorMessage = nil
    }

    private func insertVariableToken(_ key: String) {
        let token = "{{\(key)}}"
        if !bodyText.isEmpty, !bodyText.hasSuffix(" ") { bodyText += " " }
        bodyText += token
    }

    private func save() async {
        hideKeyboard()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let id = mode.templateId {
                _ = try await service.updateTemplate(
                    id: id,
                    patch: EmailTemplateUpdate(
                        workspace: mode.workspace,
                        name: n,
                        subject: s,
                        body: b,
                        variables: variables,
                        isArchived: nil
                    )
                )
            } else {
                _ = try await service.createTemplate(
                    EmailTemplateInsert(workspace: mode.workspace, name: n, subject: s, body: b, variables: variables)
                )
            }

            dismiss()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func archive() async {
        guard let id = mode.templateId else { return }

        hideKeyboard()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await service.archiveTemplate(id: id, isArchived: true)
            dismiss()
        } catch {
            errorMessage = "归档失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        EmailTemplateEditView(mode: .create(workspace: .crm))
    }
}
