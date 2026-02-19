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

    @State private var isSavePreviewPresented: Bool = false
    @State private var isPreviewPresented: Bool = false
    @State private var isTestSendPresented: Bool = false

    @State private var workspace: EstateMateWorkspaceKind

    @State private var name: String = ""
    @State private var fromName: String = ""
    @State private var subject: String = ""
    @State private var subjectSelection: NSRange = NSRange(location: 0, length: 0)
    @State private var isSubjectFocused: Bool = false

    @State private var bodyText: String = ""
    @State private var bodySelection: NSRange = NSRange(location: 0, length: 0)
    @State private var isBodyFocused: Bool = false

    @State private var variables: [EmailTemplateVariable] = []

    // AI format + save
                
    // Rich text helpers (HTML tags)
    @State private var isColorPickerPresented: Bool = false
    @State private var pickedColor: Color = EMTheme.accent

    // Test send
    @State private var testToEmail: String = ""
    @State private var isTestSending: Bool = false
    @State private var testSendResult: String?

    private let service = EmailTemplateService()
    private let gmailService = CRMGmailIntegrationService()

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
                        EMTextField(title: "名称", text: $name, prompt: "例如：Open House的模版")

                        EMTextField(title: "发件人显示名", text: $fromName, prompt: "你的姓名（用于在对方邮箱显示）")

                        Text("主题")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            CursorAwareTextField(
                                text: $subject,
                                selection: $subjectSelection,
                                isFocused: $isSubjectFocused,
                                placeholder: "例如：很高兴见到您，{{firstname}}"
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
                                return ["firstname", "first_name", "lastname", "last_name", "middle_name", "address", "date", "time", "event_title"]
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

                            Divider().overlay(EMTheme.line)


                        }
                    }

                    if !variables.isEmpty {
                        EMCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("变量")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)

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

                            }
                        }
                    }


                    Button {
                        hideKeyboard()
                        isPreviewPresented = true
                    } label: {
                        Text("预览")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())
                    .disabled(isLoading)
                    .sheet(isPresented: $isPreviewPresented) {
                        NavigationStack {
                            previewSheet
                        }
                    }

                    Button {
                        hideKeyboard()
                        testSendResult = nil
                        isTestSendPresented = true
                    } label: {
                        Text("测试发送")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())
                    .disabled(isLoading)
                    .sheet(isPresented: $isTestSendPresented) {
                        NavigationStack {
                            testSendSheet
                        }
                    }

                    Button {
                        hideKeyboard()
                        isSavePreviewPresented = true
                    } label: {
                        Text("保存")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading || !canSave))
                    .disabled(isLoading || !canSave)
                    .sheet(isPresented: $isSavePreviewPresented) {
                        NavigationStack {
                            savePreviewSheet
                        }
                    }

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
            .scrollIndicators(.hidden)
            .safeAreaPadding(.top, 8)
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
            // Create mode: do not auto-fill any content.
            // (Jason request) User must explicitly enter: name, from name, subject, body.
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
                fromName = (t.fromName ?? "")
            }
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }



    private var canSave: Bool {
        // Requirement: on create, user must fill all core fields before Save is enabled.
        // For edit, we keep the same rule to avoid accidentally saving an empty template.
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let f = fromName.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !n.isEmpty && !f.isEmpty && !s.isEmpty && !b.isEmpty
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

    private var savePreviewSheet: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("保存前预览", subtitle: "这是最终发送效果预览，确认后才会保存")

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("名称")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（未命名）" : name)
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink)

                            Divider().overlay(EMTheme.line)

                            Text("主题")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            Text(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（无主题）" : subject)
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink)

                            Divider().overlay(EMTheme.line)

                            Text("正文（最终效果）")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            HTMLWebView(html: buildFinalPreviewHTML())
                                .frame(minHeight: 280)
                        }
                    }

                    Button {
                        Task {
                            await save()
                            isSavePreviewPresented = false
                        }
                    } label: {
                        Text(isLoading ? "保存中…" : "确认保存")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading || !canSave))
                    .disabled(isLoading || !canSave)

                    Button {
                        isSavePreviewPresented = false
                    } label: {
                        Text("取消")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())
                    .disabled(isLoading)

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.top, 8)
        }
        .navigationTitle("预览")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var previewSheet: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("预览", subtitle: "这是最终发送效果预览（不会保存）")

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("主题")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            Text(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（无主题）" : subject)
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink)

                            Divider().overlay(EMTheme.line)

                            Text("正文")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            HTMLWebView(html: buildFinalPreviewHTML())
                                .frame(minHeight: 320)
                        }
                    }

                    Button {
                        isPreviewPresented = false
                    } label: {
                        Text("关闭")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.top, 8)
        }
        .navigationTitle("预览")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var testSendSheet: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("测试发送", subtitle: "输入一个邮箱地址，把当前模板发一封测试邮件")

                    if let testSendResult {
                        EMCard {
                            Text(testSendResult)
                                .font(.subheadline)
                                .foregroundStyle(testSendResult.contains("成功") ? EMTheme.accent : .red)
                        }
                    }

                    EMCard {
                        EMTextField(title: "收件人邮箱", text: $testToEmail, prompt: "例如：test@gmail.com")

                        Divider().overlay(EMTheme.line)

                        Text("预览")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(EMTheme.ink2)

                        HTMLWebView(html: buildFinalPreviewHTML())
                            .frame(minHeight: 260)
                    }

                    Button {
                        Task { await sendTestEmail() }
                    } label: {
                        Text(isTestSending ? "发送中…" : "发送测试邮件")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isTestSending))
                    .disabled(isTestSending)

                    Button {
                        isTestSendPresented = false
                    } label: {
                        Text("关闭")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())
                    .disabled(isTestSending)

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.top, 8)
        }
        .navigationTitle("测试发送")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func looksLikeHTML(_ s: String) -> Bool {
        // Very lightweight heuristic.
        return s.contains("<") && s.contains(">")
    }

    private func escapeHTML(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#039;")
    }

    private func plainTextToHTML(_ s: String) -> String {
        let escaped = escapeHTML(s)
        let withBreaks = escaped
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "<br>")
        return "<p>\(withBreaks)</p>"
    }

    /// When the user inserted simple inline HTML tags (bold/italic/color) but kept plain newlines,
    /// browsers/Gmail will collapse newlines into spaces.
    ///
    /// This helper preserves the user's paragraphs by converting newline characters to <br>.
    /// If the HTML already contains block/line-break tags, we leave it unchanged.
    private func preserveLineBreaksForSimpleHTML(_ html: String) -> String {
        let normalized = html
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")  // line separator
            .replacingOccurrences(of: "\u{2029}", with: "\n")  // paragraph separator

        let lower = normalized.lowercased()

        // If the HTML already declares explicit line/paragraph structure, don't touch it.
        // Note: we intentionally do NOT treat <div> as "already has layout" because <div> alone
        // doesn't preserve raw newlines.
        let alreadyHasLayout = lower.contains("<br") || lower.contains("<p") || lower.contains("<pre") || lower.contains("<li")
        guard !alreadyHasLayout else { return normalized }

        guard normalized.contains("\n") else { return normalized }

        // Preserve user-authored newlines.
        let withBreaks = normalized.replacingOccurrences(of: "\n", with: "<br>\n")
        return "<p>\(withBreaks)</p>"
    }

    private func wrapEmailHTML(_ inner: String) -> String {
        return "<!doctype html><html><head><meta charset=\"utf-8\" /><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" /><style>body{font-family:-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif;color:#222;line-height:1.55;padding:14px;}p{margin:0 0 10px 0;}</style></head><body>\(inner)</body></html>"
    }

    private func buildFinalPreviewHTML() -> String {
        let raw = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return wrapEmailHTML("<p>（无正文）</p>") }

        let inner: String
        if looksLikeHTML(raw) {
            inner = preserveLineBreaksForSimpleHTML(raw)
        } else {
            inner = plainTextToHTML(raw)
        }

        return wrapEmailHTML(inner)
    }

    private func htmlToPlainText(_ html: String) -> String {
        var s = html
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "</p>", with: "\n\n")
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendTestEmail() async {
        let to = testToEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard to.contains("@") else {
            testSendResult = "请输入正确的邮箱地址"
            return
        }

        isTestSending = true
        testSendResult = nil
        defer { isTestSending = false }

        do {
            let subj = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            let rawBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
            let html = rawBody.isEmpty ? nil : buildFinalPreviewHTML()

            let text: String = {
                if rawBody.isEmpty { return "" }
                if looksLikeHTML(rawBody) { return htmlToPlainText(rawBody) }
                return rawBody
            }()

            _ = try await gmailService.sendTestMessage(
                to: to,
                subject: subj.isEmpty ? "(无主题)" : subj,
                text: text.isEmpty ? "(无正文)" : text,
                html: html,
                fromName: fromName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : fromName.trimmingCharacters(in: .whitespacesAndNewlines),
                workspace: workspace
            )

            testSendResult = "发送成功"
        } catch {
            testSendResult = "发送失败：\(error.localizedDescription)"
        }
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
                        fromName: fromName.trimmingCharacters(in: .whitespacesAndNewlines),
                        isArchived: nil
                    )
                )

                // Keep the user on the edit page; just refresh content locally.
                name = n
                subject = s
                bodyText = b
                errorMessage = "已保存"
            } else {
                _ = try await service.createTemplate(
                    EmailTemplateInsert(workspace: workspace, name: n, subject: s, body: b, variables: variables, fromName: fromName.trimmingCharacters(in: .whitespacesAndNewlines))
                )

                // Creating a new template: dismiss back to list.
                dismiss()
            }
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
