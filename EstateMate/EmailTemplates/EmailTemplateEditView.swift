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



    enum AIPreviewTab: String, CaseIterable, Identifiable {
        case preview = "正式预览"
        case diff = "差异标注"
        case suggestions = "变量/校对"

        var id: String { rawValue }
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
    @State private var subject: String = ""
    @State private var subjectSelection: NSRange = NSRange(location: 0, length: 0)
    @State private var isSubjectFocused: Bool = false

    @State private var bodyText: String = ""
    @State private var bodySelection: NSRange = NSRange(location: 0, length: 0)
    @State private var isBodyFocused: Bool = false

    @State private var variables: [EmailTemplateVariable] = []

    // AI format + save
    @State private var isAIFormatting: Bool = false
    @State private var isAIPreviewPresented: Bool = false
    @State private var aiResult: EmailTemplateAIFormatService.Response?
    @State private var aiPreviewTab: AIPreviewTab = .preview

    // Rich text helpers (HTML tags)
    @State private var isColorPickerPresented: Bool = false
    @State private var pickedColor: Color = EMTheme.accent

    // Test send
    @State private var testToEmail: String = ""
    @State private var isTestSending: Bool = false
    @State private var testSendResult: String?

    private let service = EmailTemplateService()
    private let aiFormatService = EmailTemplateAIFormatService()
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
                        EMTextField(title: "名称", text: $name, prompt: "例如：感谢来访")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("名称")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(EMTheme.ink2)
                                    Text(aiResult?.name ?? "")
                                        .font(.subheadline)
                                        .foregroundStyle(EMTheme.ink)

                                    Divider().overlay(EMTheme.line)

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
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading))
                    .disabled(isLoading)
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

            // Give the user a ready-to-edit starter template (no need to know <p> / HTML).
            if subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                subject = workspace == .openhouse
                    ? "感谢您来参加 {{event_title}}"
                    : "很高兴认识您"
            }

            if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bodyText = workspace == .openhouse
                    ? "{{firstname}} 您好，\n\n感谢您今天来参加我们的活动策划！\n如果您对 {{address}} 感兴趣，欢迎随时回复我。\n\n祝您有美好的一天！"
                    : "您好，\n\n很高兴认识您！\n如果您方便，我们可以约个时间聊一下您的需求。\n\n谢谢！"
            }

            // default declared variables (optional): keep empty for now.
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
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("AI 排版预览", subtitle: "红色仅标注 AI 改动；确认后才会覆盖并保存")

                    Picker("", selection: $aiPreviewTab) {
                        ForEach(AIPreviewTab.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let notes = aiResult?.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        EMCard {
                            Text(notes)
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
                        }
                    }

                    Group {
                        switch aiPreviewTab {
                        case .preview:
                            EMCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("主题")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(EMTheme.ink2)
                                    Text(aiResult?.subject ?? "")
                                        .font(.subheadline)
                                        .foregroundStyle(EMTheme.ink)

                                    Divider().overlay(EMTheme.line)

                                    Text("正文（正式发送效果）")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(EMTheme.ink2)

                                    HTMLWebView(html: aiResult?.preview_body_html ?? "")
                                        .frame(minHeight: 260)
                                }
                            }

                        case .diff:
                            EMCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("AI 改动差异（红色标注）")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(EMTheme.ink2)
                                    HTMLWebView(html: aiResult?.diff_body_html ?? "")
                                        .frame(minHeight: 320)
                                }
                            }

                        case .suggestions:
                            EMCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("变量建议")
                                        .font(.headline)
                                        .foregroundStyle(EMTheme.ink)

                                    if (aiResult?.suggested_variables.isEmpty ?? true) {
                                        Text("暂无建议")
                                            .font(.subheadline)
                                            .foregroundStyle(EMTheme.ink2)
                                    } else {
                                        ForEach(aiResult?.suggested_variables ?? []) { s in
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("{{\(s.key)}}")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(EMTheme.accent)
                                                Text(s.label)
                                                    .font(.subheadline)
                                                    .foregroundStyle(EMTheme.ink)
                                                if let r = s.reason, !r.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                    Text(r)
                                                        .font(.footnote)
                                                        .foregroundStyle(EMTheme.ink2)
                                                }
                                                if let snip = s.original_snippet, !snip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                    Text("原文：\(snip)")
                                                        .font(.footnote)
                                                        .foregroundStyle(EMTheme.ink2)
                                                }
                                                Divider().overlay(EMTheme.line)
                                            }
                                        }
                                    }

                                    if !(aiResult?.token_corrections.isEmpty ?? true) {
                                        Divider().overlay(EMTheme.line)
                                        Text("变量名修正建议")
                                            .font(.headline)
                                            .foregroundStyle(EMTheme.ink)

                                        ForEach(aiResult?.token_corrections ?? []) { c in
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("\(c.from) → \(c.to)")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(EMTheme.ink)
                                                if let r = c.reason {
                                                    Text(r)
                                                        .font(.footnote)
                                                        .foregroundStyle(EMTheme.ink2)
                                                }
                                                Divider().overlay(EMTheme.line)
                                            }
                                        }
                                    }

                                    if !(aiResult?.token_issues.isEmpty ?? true) {
                                        Divider().overlay(EMTheme.line)
                                        Text("变量问题")
                                            .font(.headline)
                                            .foregroundStyle(EMTheme.ink)

                                        ForEach(aiResult?.token_issues ?? []) { i in
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(i.token)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.red)
                                                Text(i.message ?? "")
                                                    .font(.footnote)
                                                    .foregroundStyle(EMTheme.ink2)
                                                Divider().overlay(EMTheme.line)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        Task { await applyAIAndSave() }
                    } label: {
                        Text(isLoading ? "保存中…" : "确认并保存")
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
        }
        .navigationTitle("AI排版")
        .navigationBarTitleDisplayMode(.inline)
    }


    private func aiFormatAndPreview() async {
        hideKeyboard()
        isAIFormatting = true
        errorMessage = nil
        defer { isAIFormatting = false }

        do {
            let res = try await aiFormatService.format(workspace: workspace, name: name, subject: subject, body: bodyText, declaredKeys: variables.map(\.key))
            aiResult = res
            aiPreviewTab = .preview
            isAIPreviewPresented = true
        } catch {
            errorMessage = "AI排版失败：\(error.localizedDescription)"
        }
    }

    private func applyAIAndSave() async {
        name = aiResult?.name ?? name
        subject = aiResult?.subject ?? subject
        bodyText = aiResult?.body_html ?? bodyText
        isAIPreviewPresented = false
        await save()
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
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading))
                    .disabled(isLoading)

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

    private func wrapEmailHTML(_ inner: String) -> String {
        return "<!doctype html><html><head><meta charset=\"utf-8\" /><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" /><style>body{font-family:-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif;color:#222;line-height:1.55;padding:14px;}p{margin:0 0 10px 0;}</style></head><body>\(inner)</body></html>"
    }

    private func buildFinalPreviewHTML() -> String {
        let raw = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return wrapEmailHTML("<p>（无正文）</p>") }
        let inner = looksLikeHTML(raw) ? raw : plainTextToHTML(raw)
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
                    EmailTemplateInsert(workspace: workspace, name: n, subject: s, body: b, variables: variables)
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
