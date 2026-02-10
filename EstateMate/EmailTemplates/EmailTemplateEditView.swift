//
//  EmailTemplateEditView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI
import UIKit

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
    @State private var subjectSelection: NSRange = NSRange(location: 0, length: 0)
    @State private var isSubjectFocused: Bool = false

    @State private var bodyText: String = ""
    @State private var bodySelection: NSRange = NSRange(location: 0, length: 0)
    @State private var isBodyFocused: Bool = false

    @State private var variables: [EmailTemplateVariable] = []

    @State private var newVarKey: String = ""
    @State private var newVarKeyError: String?
    @State private var newVarLabel: String = "" // 要填写的内容

    @State private var isPreviewPresented: Bool = false

    // AI format + save
    @State private var isAIFormatting: Bool = false
    @State private var isAIPreviewPresented: Bool = false
    @State private var aiFormattedSubject: String = ""
    @State private var aiFormattedBodyHTML: String = ""
    @State private var aiFormatNotes: String?

    // Rich text helpers (HTML tags)
    @State private var isColorPickerPresented: Bool = false
    @State private var pickedColor: Color = EMTheme.accent

    private let service = EmailTemplateService()
    private let aiFormatService = EmailTemplateAIFormatService()

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

                        VStack(alignment: .leading, spacing: 8) {
                            Text("主题")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            CursorAwareTextField(
                                text: $subject,
                                selection: $subjectSelection,
                                isFocused: $isSubjectFocused,
                                placeholder: "例如：很高兴见到您，{{client_name}}"
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isSubjectFocused = true
                            }
                            .background(
                                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                    .fill(EMTheme.paper2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                    .stroke(EMTheme.line, lineWidth: 1)
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("正文")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            CursorAwareTextView(text: $bodyText, selection: $bodySelection, isFocused: $isBodyFocused)
                                .frame(minHeight: 180, maxHeight: 260)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.65))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(EMTheme.line, lineWidth: 1)
                                        )
                                )

                            // Inline formatting (HTML)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    Button {
                                        isBodyFocused = true
                                        wrapBodySelection(prefix: "<b>", suffix: "</b>")
                                    } label: {
                                        Label("加粗", systemImage: "bold")
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(EMTheme.ink)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(Color.white))
                                            .overlay(Capsule().stroke(EMTheme.line, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        isBodyFocused = true
                                        wrapBodySelection(prefix: "<i>", suffix: "</i>")
                                    } label: {
                                        Label("斜体", systemImage: "italic")
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(EMTheme.ink)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(Color.white))
                                            .overlay(Capsule().stroke(EMTheme.line, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        hideKeyboard()
                                        isBodyFocused = true
                                        isColorPickerPresented = true
                                    } label: {
                                        Label("颜色", systemImage: "paintpalette")
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(EMTheme.ink)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(Color.white))
                                            .overlay(Capsule().stroke(EMTheme.line, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .sheet(isPresented: $isColorPickerPresented) {
                                NavigationStack {
                                    Form {
                                        ColorPicker("选择颜色", selection: $pickedColor, supportsOpacity: false)
                                    }
                                    .navigationTitle("文字颜色")
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("应用") {
                                                applyPickedColorToBodySelection()
                                                isColorPickerPresented = false
                                            }
                                        }
                                        ToolbarItem(placement: .topBarLeading) {
                                            Button("取消") {
                                                isColorPickerPresented = false
                                            }
                                        }
                                    }
                                }
                            }

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
                        Task { await aiFormatAndPreview() }
                    } label: {
                        Text(isAIFormatting ? "AI排版中…" : "AI一键排版并保存")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())
                    .disabled(isLoading || isAIFormatting)
                    .sheet(isPresented: $isAIPreviewPresented) {
                        NavigationStack {
                            aiPreviewSheet
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
            .safeAreaPadding(.top, 8)
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

        // If the subject field is focused, insert into subject; otherwise insert into body.
        if isSubjectFocused {
            insertTokenIntoSubject(token)
        } else {
            insertTokenIntoBody(token)
        }
    }

    private func insertTokenIntoSubject(_ token: String) {
        let ns = subject as NSString
        let safeLoc = min(max(subjectSelection.location, 0), ns.length)
        let safeLen = min(max(subjectSelection.length, 0), ns.length - safeLoc)
        let range = NSRange(location: safeLoc, length: safeLen)

        let needsLeadingSpace: Bool = {
            guard range.location > 0 else { return false }
            let prev = ns.substring(with: NSRange(location: range.location - 1, length: 1))
            return prev != " " && prev != "\n"
        }()

        let insertion = (needsLeadingSpace ? " " : "") + token
        subject = ns.replacingCharacters(in: range, with: insertion)

        let newCursor = range.location + (insertion as NSString).length
        subjectSelection = NSRange(location: newCursor, length: 0)
    }

    private func insertTokenIntoBody(_ token: String) {
        let ns = bodyText as NSString
        let safeLoc = min(max(bodySelection.location, 0), ns.length)
        let safeLen = min(max(bodySelection.length, 0), ns.length - safeLoc)
        let range = NSRange(location: safeLoc, length: safeLen)

        let needsLeadingSpace: Bool = {
            guard range.location > 0 else { return false }
            let prev = ns.substring(with: NSRange(location: range.location - 1, length: 1))
            return prev != " " && prev != "\n"
        }()

        let insertion = (needsLeadingSpace ? " " : "") + token
        bodyText = ns.replacingCharacters(in: range, with: insertion)

        let newCursor = range.location + (insertion as NSString).length
        bodySelection = NSRange(location: newCursor, length: 0)
    }

    private func wrapBodySelection(prefix: String, suffix: String) {
        let ns = bodyText as NSString
        let safeLoc = min(max(bodySelection.location, 0), ns.length)
        let safeLen = min(max(bodySelection.length, 0), ns.length - safeLoc)
        let range = NSRange(location: safeLoc, length: safeLen)

        if range.length == 0 {
            // Insert empty tag pair and place cursor inside.
            let insertion = prefix + suffix
            bodyText = ns.replacingCharacters(in: range, with: insertion)
            bodySelection = NSRange(location: range.location + (prefix as NSString).length, length: 0)
        } else {
            let selected = ns.substring(with: range)
            let wrapped = prefix + selected + suffix
            bodyText = ns.replacingCharacters(in: range, with: wrapped)
            bodySelection = NSRange(location: range.location + (wrapped as NSString).length, length: 0)
        }
    }

    private func applyPickedColorToBodySelection() {
        guard let hex = EMTheme.hexFromColor(pickedColor) else { return }
        wrapBodySelection(prefix: "<span style=\"color:\(hex)\">", suffix: "</span>")
    }

    private var aiPreviewSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                EMSectionHeader("AI 排版预览", subtitle: "确认后会覆盖当前主题/正文并立即保存")

                if let aiFormatNotes, !aiFormatNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EMCard {
                        Text(aiFormatNotes)
                            .font(.footnote)
                            .foregroundStyle(EMTheme.ink2)
                    }
                }

                EMCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("原主题")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(EMTheme.ink2)
                        Text(subject.isEmpty ? "（无）" : subject)
                            .font(.subheadline)
                            .foregroundStyle(EMTheme.ink)

                        Divider().overlay(EMTheme.line)

                        Text("原正文")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(EMTheme.ink2)
                        Text(bodyText.isEmpty ? "（无）" : bodyText)
                            .font(.footnote)
                            .foregroundStyle(EMTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                EMCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI排版后主题")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(EMTheme.ink2)
                        Text(aiFormattedSubject.isEmpty ? "（无）" : aiFormattedSubject)
                            .font(.subheadline)
                            .foregroundStyle(EMTheme.ink)

                        Divider().overlay(EMTheme.line)

                        Text("AI排版后正文（HTML）")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(EMTheme.ink2)
                        Text(aiFormattedBodyHTML.isEmpty ? "（无）" : aiFormattedBodyHTML)
                            .font(.footnote)
                            .foregroundStyle(EMTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                Button {
                    Task { await applyAIAndSave() }
                } label: {
                    Text(isLoading ? "保存中…" : "应用并保存")
                }
                .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading))
                .disabled(isLoading)

                Button {
                    isAIPreviewPresented = false
                } label: {
                    Text("取消")
                }
                .buttonStyle(EMSecondaryButtonStyle())
                .disabled(isLoading)

                Spacer(minLength: 20)
            }
            .padding(EMTheme.padding)
        }
        .safeAreaPadding(.top, 8)
        .navigationTitle("AI排版")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aiFormatAndPreview() async {
        hideKeyboard()
        isAIFormatting = true
        errorMessage = nil
        defer { isAIFormatting = false }

        do {
            let res = try await aiFormatService.format(workspace: workspace, subject: subject, body: bodyText)
            aiFormattedSubject = res.subject
            aiFormattedBodyHTML = res.body_html
            aiFormatNotes = res.notes
            isAIPreviewPresented = true
        } catch {
            errorMessage = "AI排版失败：\(error.localizedDescription)"
        }
    }

    private func applyAIAndSave() async {
        subject = aiFormattedSubject
        bodyText = aiFormattedBodyHTML
        isAIPreviewPresented = false
        await save()
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
            .safeAreaPadding(.top, 8)
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
