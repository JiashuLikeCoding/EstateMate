//
//  EmailTemplateEditView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Supabase
import Foundation

// WYSIWYG body editor


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

    @State private var bodyAttributed: NSAttributedString = NSAttributedString(string: "")
    @State private var bodySelection: NSRange = NSRange(location: 0, length: 0)
    @State private var isBodyFocused: Bool = false

    /// If we loaded the body from HTML and the user hasn't edited it yet,
    /// keep the original HTML source so preview/test-send can preserve tags like <b> reliably.
    @State private var bodyHTMLSourceIfUnedited: String? = nil

    @State private var variables: [EmailTemplateVariable] = []
    @State private var attachments: [EmailTemplateAttachment] = []

    @State private var isAttachmentPickerPresented: Bool = false
    @State private var isUploadingAttachment: Bool = false
    @State private var attachmentStatusMessage: String? = nil

    private struct Snapshot: Equatable {
        var workspace: EstateMateWorkspaceKind
        var name: String
        var fromName: String
        var subject: String
        var bodyPlain: String
        var variables: [EmailTemplateVariable]
        var attachments: [EmailTemplateAttachment]
    }

    @State private var initialSnapshot: Snapshot? = nil
    @State private var isBackConfirmPresented: Bool = false

    // AI format + save
                
    // Rich text helpers (HTML tags)
    @State private var isColorPickerPresented: Bool = false
    @State private var pickedColor: Color = EMTheme.accent

    // Test send
    @State private var testToEmail: String = ""
    @State private var isTestSending: Bool = false
    @State private var testSendResult: String?
    @State private var testVariableOverrides: [String: String] = [:]

    private let service = EmailTemplateService()
    private let gmailService = CRMGmailIntegrationService()

    private let client = SupabaseClientProvider.client

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

                            RichTextEditorView(
                                attributedText: $bodyAttributed,
                                selection: $bodySelection,
                                isFocused: $isBodyFocused,
                                onUserEdit: {
                                    bodyHTMLSourceIfUnedited = nil
                                }
                            )
                                .frame(minHeight: 180, maxHeight: 260)
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
                                        bodyAttributed = RichTextFormatting.toggle(.bold, in: bodyAttributed, range: bodySelection)
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
                                        bodyAttributed = RichTextFormatting.toggle(.italic, in: bodyAttributed, range: bodySelection)
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
                                // Prefer legacy keys (no underscore) for consistency in the UI.
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

                            Divider().overlay(EMTheme.line)


                        }
                    }

                    // NOTE: Attachments are no longer managed on email templates.
                    // They are now bound to activities (events) for auto-reply emails.

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
                        prepareTestSendOverrides()
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    hideKeyboard()
                    if isLoading {
                        return
                    }
                    if isDirty {
                        isBackConfirmPresented = true
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
            }
        }
        .alert("未保存的修改", isPresented: $isBackConfirmPresented) {
            if canSave {
                Button("保存") {
                    Task {
                        await save()
                        // If we're still on this screen (edit mode), refresh the baseline.
                        if mode.templateId != nil {
                            initialSnapshot = currentSnapshot
                        }
                    }
                }
            }

            Button("不保存", role: .destructive) {
                dismiss()
            }

            Button("继续编辑", role: .cancel) {}
        } message: {
            if canSave {
                Text("你有未保存的修改，是否需要保存？")
            } else {
                Text("你有未保存的修改（且当前内容不完整，无法保存）。是否直接退出？")
            }
        }
        /*
        .fileImporter(
            isPresented: $isAttachmentPickerPresented,
            allowedContentTypes: [.pdf, .image, .data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                Task { await handlePickedAttachments(urls) }
            case let .failure(error):
                attachmentStatusMessage = "选择失败：\(error.localizedDescription)"
            }
        }
        */
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
            attachments = []
            initialSnapshot = currentSnapshot
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
                // Load body as rich text (HTML) when possible.
                // Note: some legacy templates store "simple HTML" (inline tags) with raw newlines.
                // HTML collapses raw newlines, so we convert them to <br> for correct display in the editor.
                if looksLikeHTML(t.body) {
                    let prepared = preserveLineBreaksForSimpleHTML(t.body)
                    bodyHTMLSourceIfUnedited = prepared
                    bodyAttributed = .fromHTML(prepared)
                } else {
                    bodyHTMLSourceIfUnedited = nil
                    // Some templates were saved with literal "\\n" sequences instead of real newlines.
                    // Convert those to real line breaks for correct WYSIWYG display.
                    bodyAttributed = NSAttributedString(string: unescapeCommonNewlines(t.body))
                }
                variables = t.variables
                // Attachments are no longer managed on templates.
                attachments = []
                fromName = (t.fromName ?? "")

                initialSnapshot = currentSnapshot
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
        let b = bodyAttributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return !n.isEmpty && !f.isEmpty && !s.isEmpty && !b.isEmpty
    }

    private var currentSnapshot: Snapshot {
        Snapshot(
            workspace: workspace,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            fromName: fromName.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            bodyPlain: bodyAttributed.string.trimmingCharacters(in: .whitespacesAndNewlines),
            variables: variables,
            attachments: []
        )
    }

    private var isDirty: Bool {
        guard let initialSnapshot else {
            // If we haven't loaded yet, do not block navigation.
            return false
        }
        return currentSnapshot != initialSnapshot
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
        let plain = bodyAttributed.string as NSString
        let safeLoc = min(max(bodySelection.location, 0), plain.length)
        let safeLen = min(max(bodySelection.length, 0), plain.length - safeLoc)
        let range = NSRange(location: safeLoc, length: safeLen)

        let needsLeadingSpace: Bool = {
            guard range.location > 0 else { return false }
            let prev = plain.substring(with: NSRange(location: range.location - 1, length: 1))
            return prev != " " && prev != "\n"
        }()

        let insertion = (needsLeadingSpace ? " " : "") + token

        let mutable = NSMutableAttributedString(attributedString: bodyAttributed)
        let attrs: [NSAttributedString.Key: Any] = {
            guard mutable.length > 0 else {
                return [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.label]
            }
            let idx = max(0, min(range.location, mutable.length - 1))
            return mutable.attributes(at: idx, effectiveRange: nil)
        }()
        mutable.replaceCharacters(in: range, with: NSAttributedString(string: insertion, attributes: attrs))
        bodyAttributed = mutable

        let newCursor = range.location + (insertion as NSString).length
        bodySelection = NSRange(location: newCursor, length: 0)
    }

    // wrapBodySelection removed: body is edited as rich text (WYSIWYG) now.

    private func applyPickedColorToBodySelection() {
        guard let hex = EMTheme.hexFromColor(pickedColor) else { return }
        let uiColor = UIColor(hexString: hex) ?? UIColor.label
        bodyAttributed = RichTextFormatting.applyColor(uiColor, in: bodyAttributed, range: bodySelection)
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
                            subjectPreviewText(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（无主题）" : subject)
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
                            subjectPreviewText(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（无主题）" : subject)
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

                        if !usedVariableKeysForTestSend().isEmpty {
                            Divider().overlay(EMTheme.line)

                            Text("变量值")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(usedVariableKeysForTestSend(), id: \.self) { key in
                                    EMTextField(
                                        title: "{{\(key)}}",
                                        text: Binding(
                                            get: { testVariableOverrides[key] ?? "" },
                                            set: { testVariableOverrides[key] = $0 }
                                        ),
                                        prompt: defaultTestValuePrompt(for: key)
                                    )
                                }
                            }
                        }

                        Divider().overlay(EMTheme.line)

                        Text("预览")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(EMTheme.ink2)

                        HTMLWebView(html: buildFinalEmailHTMLForSend(overrides: testVariableOverrides))
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

    private func extractVariableKeys(from text: String) -> [String] {
        let pattern = "\\{\\{([^{}]+)\\}\\}" // capture inside {{...}}
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        var keys: [String] = []
        for m in regex.matches(in: text, range: full) {
            guard m.numberOfRanges >= 2 else { continue }
            let raw = ns.substring(with: m.range(at: 1))
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            keys.append(key)
        }

        // De-dupe while preserving first-seen order
        var seen = Set<String>()
        var out: [String] = []
        for k in keys {
            if !seen.contains(k) {
                seen.insert(k)
                out.append(k)
            }
        }
        return out
    }

    private func usedVariableKeysForTestSend() -> [String] {
        let subjectKeys = extractVariableKeys(from: subject)

        let bodySourceForScan: String = {
            if let src = bodyHTMLSourceIfUnedited, !src.isEmpty {
                return src
            }
            // scan the displayed plain string; tokens are visible to the user in WYSIWYG
            return bodyAttributed.string
        }()

        let bodyKeys = extractVariableKeys(from: bodySourceForScan)

        // De-dupe
        var seen = Set<String>()
        var all: [String] = []
        for k in (subjectKeys + bodyKeys) {
            if !seen.contains(k) {
                seen.insert(k)
                all.append(k)
            }
        }

        // Sort for stable UX (firstname/lastname at top when present)
        let preferred = ["firstname", "lastname", "address", "date", "time", "event_title"]
        return all.sorted { a, b in
            let ia = preferred.firstIndex(of: a) ?? Int.max
            let ib = preferred.firstIndex(of: b) ?? Int.max
            if ia != ib { return ia < ib }
            return a < b
        }
    }

    private func defaultTestValuePrompt(for key: String) -> String {
        let lower = key.lowercased()
        switch lower {
        case "firstname": return "例如：Jason"
        case "lastname": return "例如：Chen"
        case "middle_name": return "例如：(可留空)"
        case "address": return "例如：123 Main St"
        case "date": return "例如：2026-02-19"
        case "time": return "例如：2:00 PM"
        case "event_title": return "例如：Open House"
        default:
            if let v = variables.first(where: { $0.key.lowercased() == lower }), !v.example.isEmpty {
                return "例如：\(v.example)"
            }
            return "例如：..."
        }
    }

    private func defaultTestValue(for key: String) -> String {
        let lower = key.lowercased()
        switch lower {
        case "firstname": return "Jason"
        case "lastname": return "Chen"
        case "middle_name": return ""
        case "address": return "123 Main St"
        case "date": return "2026-02-19"
        case "time": return "2:00 PM"
        case "event_title": return "Open House"
        default:
            if let v = variables.first(where: { $0.key.lowercased() == lower }), !v.example.isEmpty {
                return v.example
            }
            return ""
        }
    }

    /// Ensure test-send overrides contains at least default values for any used variables.
    /// (Jason chose option B: auto-fill common variables with examples.)
    private func prepareTestSendOverrides() {
        let used = usedVariableKeysForTestSend()
        guard !used.isEmpty else { return }

        var next = testVariableOverrides
        for k in used {
            if next[k] == nil {
                next[k] = defaultTestValue(for: k)
            }
        }
        testVariableOverrides = next
    }

    private func subjectPreviewText(_ s: String) -> Text {
        let base = s
        // Highlight {{var}} tokens in the preview UI with deep green.
        let pattern = "\\{\\{[^{}]+\\}\\}" // simple + safe
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return Text(base) }

        let ns = base as NSString
        let full = NSRange(location: 0, length: ns.length)

        var chunks: [Text] = []
        var cursor = 0

        let matches = regex.matches(in: base, range: full)
        for m in matches {
            let r = m.range
            if r.location > cursor {
                let part = ns.substring(with: NSRange(location: cursor, length: r.location - cursor))
                chunks.append(Text(part))
            }

            let token = ns.substring(with: r)
            chunks.append(Text(token).foregroundStyle(Color(red: 11/255, green: 90/255, blue: 42/255)))
            cursor = r.location + r.length
        }

        if cursor < ns.length {
            chunks.append(Text(ns.substring(from: cursor)))
        }

        return chunks.reduce(Text("")) { $0 + $1 }
    }

    private func highlightTemplateVariablesInHTML(_ html: String) -> String {
        // Wrap {{var}} tokens so CSS can color them in the preview WebView.
        // This is for preview only; we do NOT persist it.
        let pattern = "\\{\\{[^{}]+\\}\\}" // simple + safe
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }

        let full = NSRange(location: 0, length: (html as NSString).length)
        return regex.stringByReplacingMatches(in: html, range: full, withTemplate: "<span class=\"em-var\">$0</span>")
    }

    private func unescapeCommonNewlines(_ s: String) -> String {
        // Handle legacy content that contains literal backslash sequences like "\\n".
        // We only target newline-related escapes to avoid surprising other backslashes.
        return s
            .replacingOccurrences(of: "\\r\\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\n")
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
        // Deep green for template variable tokens + link color.
        let varColor = "#0B5A2A"
        return "<!doctype html><html><head><meta charset=\"utf-8\" /><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" /><style>body{font-family:-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif;color:#222;line-height:1.55;margin:0;padding:0;}p{margin:0 0 10px 0;}a{color:\(varColor);text-decoration:underline;word-break:break-word;}span.em-var{color:\(varColor);font-weight:700;}b,strong{font-weight:700;}</style></head><body>\(inner)</body></html>"
    }

    private func extractBodyInnerHTML(_ fullHTML: String) -> String {
        // NSAttributedString html export often emits a full HTML doc.
        // We only want the <body> inner HTML so we can wrap with our own consistent styles.
        let lower = fullHTML.lowercased()
        guard let bodyStart = lower.range(of: "<body"), let bodyTagEnd = lower[bodyStart.upperBound...].range(of: ">") else {
            return fullHTML
        }
        let contentStart = bodyTagEnd.upperBound
        guard let bodyEnd = lower.range(of: "</body>") else {
            return String(fullHTML[contentStart...])
        }
        return String(fullHTML[contentStart..<bodyEnd.lowerBound])
    }

    private func bodyInnerHTMLFromAttributed() -> String? {
        guard let full = bodyAttributed.toHTML() else { return nil }
        let inner = extractBodyInnerHTML(full).trimmingCharacters(in: .whitespacesAndNewlines)
        return inner.isEmpty ? nil : inner
    }

    private func buildFinalPreviewHTML() -> String {
        let plain = bodyAttributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if plain.isEmpty { return wrapEmailHTML("<p>（无正文）</p>") }

        // Prefer the original HTML source (if unedited) so tags like <b> keep working.
        if let src = bodyHTMLSourceIfUnedited, !src.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let styled = highlightTemplateVariablesInHTML(src)
            return wrapEmailHTML(styled)
        }

        if let inner = bodyInnerHTMLFromAttributed() {
            let styled = highlightTemplateVariablesInHTML(inner)
            return wrapEmailHTML(styled)
        }

        // Fallback (should be rare)
        return wrapEmailHTML(highlightTemplateVariablesInHTML(plainTextToHTML(plain)))
    }

    /// Build the final email HTML for sending, with variables rendered (no preview highlighting).
    private func buildFinalEmailHTMLForSend(overrides: [String: String]) -> String {
        let plain = bodyAttributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if plain.isEmpty { return wrapEmailHTML("<p>（无正文）</p>") }

        // Prefer the original HTML source (if unedited) so tags like <b> keep working.
        if let src = bodyHTMLSourceIfUnedited, !src.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let rendered = EmailTemplateRenderer.render(src, variables: variables, overrides: overrides)
            return wrapEmailHTML(rendered)
        }

        if let inner = bodyInnerHTMLFromAttributed() {
            let rendered = EmailTemplateRenderer.render(inner, variables: variables, overrides: overrides)
            return wrapEmailHTML(rendered)
        }

        // Fallback
        let rendered = EmailTemplateRenderer.render(plainTextToHTML(plain), variables: variables, overrides: overrides)
        return wrapEmailHTML(rendered)
    }

    private func sendTestEmail() async {
        let to = testToEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard to.contains("@") else {
            testSendResult = "请输入正确的邮箱地址"
            return
        }

        // Make sure we have defaults for any used keys before sending.
        prepareTestSendOverrides()

        isTestSending = true
        testSendResult = nil
        defer { isTestSending = false }

        do {
            let subjRaw = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            let subjRendered = EmailTemplateRenderer.render(subjRaw, variables: variables, overrides: testVariableOverrides)

            let plainRaw = bodyAttributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
            let plainRendered = EmailTemplateRenderer.render(plainRaw, variables: variables, overrides: testVariableOverrides)

            let html = plainRaw.isEmpty ? nil : buildFinalEmailHTMLForSend(overrides: testVariableOverrides)

            _ = try await gmailService.sendTestMessage(
                to: to,
                subject: subjRendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(无主题)" : subjRendered,
                text: plainRendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(无正文)" : plainRendered,
                html: html,
                fromName: fromName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : fromName.trimmingCharacters(in: .whitespacesAndNewlines),
                attachments: [],
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
        let bodyPlain = bodyAttributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyHTML = bodyInnerHTMLFromAttributed() ?? bodyPlain

        do {
            if let id = mode.templateId {
                _ = try await service.updateTemplate(
                    id: id,
                    patch: EmailTemplateUpdate(
                        workspace: workspace,
                        name: n,
                        subject: s,
                        body: bodyHTML,
                        variables: variables,
                        attachments: [],
                        fromName: fromName.trimmingCharacters(in: .whitespacesAndNewlines),
                        isArchived: nil
                    )
                )

                // Keep the user on the edit page; just refresh content locally.
                name = n
                subject = s
                bodyAttributed = looksLikeHTML(bodyHTML) ? .fromHTML(preserveLineBreaksForSimpleHTML(bodyHTML)) : NSAttributedString(string: bodyHTML)
                errorMessage = "已保存"
                initialSnapshot = currentSnapshot
            } else {
                _ = try await service.createTemplate(
                    EmailTemplateInsert(
                        workspace: workspace,
                        name: n,
                        subject: s,
                        body: bodyHTML,
                        variables: variables,
                        attachments: [],
                        fromName: fromName.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
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

    private func handlePickedAttachments(_ urls: [URL]) async {
        guard let templateId = mode.templateId else {
            attachmentStatusMessage = "请先保存模板，再添加附件"
            return
        }

        isUploadingAttachment = true
        attachmentStatusMessage = nil
        defer { isUploadingAttachment = false }

        do {
            for url in urls {
                // fileImporter returns security-scoped URLs. We must access them properly,
                // otherwise Data(contentsOf:) may fail with "no permission".
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                }

                let data: Data = try {
                    do {
                        return try Data(contentsOf: url)
                    } catch {
                        // Fallback: coordinate read (some providers require it).
                        let coordinator = NSFileCoordinator()
                        var readError: NSError?
                        var resultData: Data?
                        coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { readURL in
                            resultData = try? Data(contentsOf: readURL)
                        }
                        if let readError { throw readError }
                        if let resultData { return resultData }
                        throw error
                    }
                }()

                let rawName = (url.lastPathComponent.isEmpty ? "附件" : url.lastPathComponent)
                let filename = rawName.removingPercentEncoding ?? rawName
                let ext = url.pathExtension

                let mimeType: String? = {
                    if let ut = UTType(filenameExtension: ext),
                       let preferred = ut.preferredMIMEType {
                        return preferred
                    }
                    if ext.lowercased() == "pdf" { return "application/pdf" }
                    return "application/octet-stream"
                }()

                let safeFilename: String = {
                    // Supabase Storage object keys are picky; avoid %, spaces, and non-ascii.
                    let cleaned = filename
                        .replacingOccurrences(of: "/", with: "_")
                        .replacingOccurrences(of: "\\\\", with: "_")

                    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._- ")
                    let ascii = cleaned.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
                    let collapsed = String(ascii)
                        .replacingOccurrences(of: " ", with: "_")
                        .replacingOccurrences(of: "__", with: "_")

                    let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
                    return trimmed.isEmpty ? "attachment.pdf" : trimmed
                }()

                let path = "\(templateId.uuidString)/\(UUID().uuidString)_\(safeFilename)"

                _ = try await client.storage
                    .from("email_attachments")
                    .upload(path, data: data, options: FileOptions(contentType: mimeType, upsert: true))

                let item = EmailTemplateAttachment(
                    storagePath: path,
                    filename: filename,
                    mimeType: mimeType,
                    sizeBytes: data.count
                )

                // Replace if same path exists (shouldn't), otherwise append.
                attachments.removeAll { $0.storagePath == item.storagePath }
                attachments.append(item)
            }

            attachmentStatusMessage = "已添加附件（记得点保存）"
        } catch {
            attachmentStatusMessage = "上传失败：\(error.localizedDescription)"
        }
    }

    private func removeAttachment(_ a: EmailTemplateAttachment) async {
        // Remove from local list; do not force-save here.
        attachments.removeAll { $0.storagePath == a.storagePath }

        // Best-effort delete from Storage as well.
        do {
            try await client.storage
                .from("email_attachments")
                .remove(paths: [a.storagePath])
        } catch {
            // Keep silent; user can still save the template state.
        }

        attachmentStatusMessage = "已移除附件（记得点保存）"
    }
}


#Preview {
    NavigationStack {
        EmailTemplateEditView(mode: .create(workspace: .crm))
    }
}
