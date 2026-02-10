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

    init(mode: Mode) {
        self.mode = mode
        _workspace = State(initialValue: mode.workspace)
    }

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var workspace: EstateMateWorkspaceKind

    @State private var name: String = ""
    @State private var subject: String = ""
    @State private var bodyText: String = ""

    @State private var variables: [EmailTemplateVariable] = []

    @State private var newVarKey: String = ""
    @State private var newVarKeyError: String?
    @State private var newVarLabel: String = "" // 要填写的内容

    @State private var isPreviewPresented: Bool = false

    private let service = EmailTemplateService()

    private var builtInPreviewOverrides: [String: String] {
        guard workspace == .openhouse else { return [:] }
        return [
            "firstname": "小明",
            "lastname": "张",
            "middle_name": "",
            "address": "123 Example St",
            "date": "2026-02-10",
            "time": "14:00",
            "event_title": "周末开放日",
            "client_name": "张小明",
            "client_email": "test@example.com"
        ]
    }

    var renderedSubject: String {
        // For quick inline preview.
        EmailTemplateRenderer.render(subject, variables: variables, overrides: builtInPreviewOverrides)
    }

    var renderedBody: String {
        EmailTemplateRenderer.render(bodyText, variables: variables, overrides: builtInPreviewOverrides)
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
                        EMTextField(title: "名称", text: $name, prompt: "例如：感谢来访")
                        EMTextField(title: "主题", text: $subject, prompt: "例如：很高兴见到您，{{client_name}}")

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

                            let builtInKeys: [String] = {
                                guard workspace == .openhouse else { return [] }
                                return ["firstname", "lastname", "middle_name", "address", "date", "time", "event_title"]
                            }()

                            if !(variables.isEmpty && builtInKeys.isEmpty) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(builtInKeys, id: \.self) { key in
                                            Button {
                                                insertVariableToken(key)
                                            } label: {
                                                Text("+ {{\(key)}}")
                                                    .font(.footnote.weight(.medium))
                                                    .foregroundStyle(EMTheme.accent)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Capsule().fill(EMTheme.accent.opacity(0.10)))
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        ForEach(variables) { v in
                                            Button {
                                                insertVariableToken(v.key)
                                            } label: {
                                                Text("+ {{\(v.key)}}")
                                                    .font(.footnote.weight(.medium))
                                                    .foregroundStyle(EMTheme.accent)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Capsule().fill(EMTheme.accent.opacity(0.10)))
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
                                    Text(v.label.isEmpty ? "（未填写提示）" : v.label)
                                        .font(.subheadline)
                                        .foregroundStyle(EMTheme.ink)
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
                                .onChange(of: newVarKey) { _, _ in
                                    newVarKeyError = nil
                                }

                            if let newVarKeyError {
                                Text(newVarKeyError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .padding(.top, -4)
                            }

                            Text("格式要求：仅支持 a-z / 0-9 / _，会自动转小写并移除其它字符")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.top, newVarKeyError == nil ? -4 : 0)

                            EMTextField(title: "要填写的内容", text: $newVarLabel, prompt: "例如：客户姓名 / 活动地址 / 经纪人姓名" )

                            Text("说明：这是预览时要让你填写的内容提示（会用在预览页输入框标题）。")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.top, -4)

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

                            Text("点击预览后，会先让你填写每个变量的内容，然后展示整封邮件。")
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink2)

                            Button {
                                hideKeyboard()
                                isPreviewPresented = true
                            } label: {
                                Text("预览")
                            }
                            .buttonStyle(EMSecondaryButtonStyle())
                        }
                    }
                    .sheet(isPresented: $isPreviewPresented) {
                        NavigationStack {
                            EmailTemplatePreviewView(subject: subject, bodyText: bodyText, variables: variables)
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
            variables = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // MVP: list+find by workspace; small dataset.
            let all = try await service.listTemplates(workspace: nil, includeArchived: true)
            if let t = all.first(where: { $0.id == id }) {
                workspace = t.workspace
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
            newVarKeyError = "变量 key 不能为空（仅支持 a-z / 0-9 / _）"
            return
        }

        if variables.contains(where: { $0.key == key }) {
            newVarKeyError = "变量 key 重复：\(key)"
            return
        }

        let label = newVarLabel.trimmingCharacters(in: .whitespacesAndNewlines)

        variables.append(.init(key: key, label: label))
        newVarKey = ""
        newVarKeyError = nil
        newVarLabel = ""
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
                        workspace: workspace,
                        name: n,
                        subject: s,
                        body: b,
                        variables: variables,
                        isArchived: nil
                    )
                )
            } else {
                _ = try await service.createTemplate(
                    EmailTemplateInsert(workspace: workspace, name: n, subject: s, body: b, variables: variables)
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

private struct EmailTemplatePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let subject: String
    let bodyText: String
    let variables: [EmailTemplateVariable]

    @State private var values: [String: String] = [:]

    var renderedSubject: String {
        EmailTemplateRenderer.render(subject, variables: variables, overrides: values)
    }

    var renderedBody: String {
        EmailTemplateRenderer.render(bodyText, variables: variables, overrides: values)
    }

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("预览邮件", subtitle: variables.isEmpty ? "无变量" : "先填写变量，再查看完整邮件")

                    if !variables.isEmpty {
                        EMCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("填写变量")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)

                                ForEach(variables) { v in
                                    VStack(alignment: .leading, spacing: 8) {
                                        let title = v.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? v.key : v.label

                                        EMTextField(
                                            title: title,
                                            text: Binding(
                                                get: { values[v.key, default: ""] },
                                                set: { values[v.key] = $0 }
                                            ),
                                            prompt: "对应 {{\(v.key)}}"
                                        )

                                        Text("token：{{\(v.key)}}")
                                            .font(.footnote)
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                }
                            }
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("主题")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            Text(renderedSubject.isEmpty ? "（无主题）" : renderedSubject)
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink)

                            Divider().overlay(EMTheme.line)

                            Text("正文")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            Text(renderedBody.isEmpty ? "（无正文）" : renderedBody)
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("关闭")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: false))

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("预览")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture { hideKeyboard() }
    }
}

#Preview {
    NavigationStack {
        EmailTemplateEditView(mode: .create(workspace: .crm))
    }
}
