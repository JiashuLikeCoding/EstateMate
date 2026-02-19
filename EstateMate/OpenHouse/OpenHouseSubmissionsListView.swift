//
//  OpenHouseSubmissionsListView.swift
//  EstateMate
//

import SwiftUI
import UIKit
import Supabase

struct OpenHouseSubmissionsListView: View {
    @Environment(\.dismiss) private var dismiss

    private let service = DynamicFormService()

    let event: OpenHouseEventV2

    @State private var formsById: [UUID: FormRecord] = [:]
    @State private var submissions: [SubmissionV2] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var selectedSubmission: SubmissionV2?
    @State private var showEditSheet = false

    @State private var showDeleteConfirm = false

    @State private var showTagPicker = false

    // Export
    @State private var isSelecting = false
    @State private var selectedIds: Set<UUID> = []
    @State private var isAllSelected = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        EMScreen(nil) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(event.title, subtitle: "已提交的访客登记")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    if isLoading {
                        EMCard {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    } else if submissions.isEmpty {
                        EMCard {
                            Text("暂无提交")
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.vertical, 10)
                        }
                    } else {
                        ForEach(submissions) { s in
                            EMCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        if isSelecting {
                                            Button {
                                                toggleSelection(s.id)
                                            } label: {
                                                Image(systemName: selectedIds.contains(s.id) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedIds.contains(s.id) ? EMTheme.accent : EMTheme.ink2)
                                                    .font(.title3)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(selectedIds.contains(s.id) ? "取消选择" : "选择")
                                        }

                                        Text(s.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(EMTheme.ink2)

                                        Spacer()

                                        HStack(spacing: 10) {
                                            Button {
                                                selectedSubmission = s
                                                showTagPicker = true
                                            } label: {
                                                Image(systemName: "tag")
                                                    .foregroundStyle(EMTheme.ink2)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("添加标签")

                                            Button {
                                                selectedSubmission = s
                                                showEditSheet = true
                                            } label: {
                                                Image(systemName: "pencil")
                                                    .foregroundStyle(EMTheme.ink2)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("编辑")
                                            .disabled(formForSubmission(s) == nil)
                                            .opacity(formForSubmission(s) == nil ? 0.4 : 1)
                                        }
                                    }

                                    if let tags = s.tags, tags.isEmpty == false {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(tags, id: \.self) { t in
                                                    EMChip(text: t, isOn: true)
                                                }
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        let pairs = displayPairs(for: s)

                                        if pairs.isEmpty {
                                            Text(formsById.isEmpty ? "字段加载中..." : "暂无可显示的字段")
                                                .font(.callout)
                                                .foregroundStyle(EMTheme.ink2)
                                                .padding(.vertical, 2)
                                        } else {
                                            ForEach(pairs, id: \.0) { label, value in
                                                HStack(alignment: .firstTextBaseline) {
                                                    Text(label)
                                                        .font(.caption)
                                                        .foregroundStyle(EMTheme.ink2)
                                                        .frame(width: 90, alignment: .leading)
                                                    Text(value)
                                                        .font(.callout)
                                                        .foregroundStyle(EMTheme.ink)
                                                    Spacer(minLength: 0)
                                                }
                                            }
                                        }
                                    }

                                    HStack {
                                        if isSelecting {
                                            Text(selectedIds.contains(s.id) ? "已选择" : "")
                                                .font(.caption)
                                                .foregroundStyle(EMTheme.ink2)
                                        }

                                        Spacer()

                                        Button {
                                            selectedSubmission = s
                                            showDeleteConfirm = true
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                                .padding(.top, 4)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("删除")
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回") {
                    dismiss()
                }
                .foregroundStyle(EMTheme.ink2)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleSelecting()
                } label: {
                    Text(isSelecting ? "完成" : "下载")
                        .foregroundStyle(EMTheme.ink)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelecting ? "结束选择" : "下载数据")
                .disabled(submissions.isEmpty)
                .opacity(submissions.isEmpty ? 0.4 : 1)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                exportBar
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showEditSheet) {
            if let selectedSubmission, let form = formForSubmission(selectedSubmission) {
                NavigationStack {
                    SubmissionEditView(
                        service: service,
                        form: form,
                        submission: selectedSubmission,
                        onSaved: { updated in
                            if let idx = submissions.firstIndex(where: { $0.id == updated.id }) {
                                submissions[idx] = updated
                            }
                        }
                    )
                }
            }
        }
        .alert("删除这条提交？", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                Task { await deleteSelected() }
            }
            Button("取消", role: .cancel) {
                selectedSubmission = nil
            }
        } message: {
            Text("删除后无法恢复")
        }
        .sheet(isPresented: $showTagPicker) {
            NavigationStack {
                SubmissionTagPickerView(
                    service: service,
                    submission: selectedSubmission,
                    onSaved: { updated in
                        if let idx = submissions.firstIndex(where: { $0.id == updated.id }) {
                            submissions[idx] = updated
                        }
                    }
                )
            }
        }
    }

    private func formForSubmission(_ submission: SubmissionV2) -> FormRecord? {
        let id = submission.formId ?? event.formId
        return formsById[id]
    }

    private var exportBar: some View {
        VStack(spacing: 10) {
            Divider().overlay(EMTheme.line)

            HStack(spacing: 10) {
                Button(isAllSelected ? "取消全选" : "全选") {
                    toggleSelectAll()
                }
                .buttonStyle(.bordered)

                Text("已选 \(selectedIds.count) 条")
                    .font(.footnote)
                    .foregroundStyle(EMTheme.ink2)

                Spacer()

                Button("导出") {
                    exportSelected()
                }
                .buttonStyle(EMPrimaryButtonStyle(disabled: selectedIds.isEmpty))
                .disabled(selectedIds.isEmpty)
            }
            .padding(.horizontal, EMTheme.padding)
            .padding(.bottom, 10)
            .padding(.top, 2)
            .background(EMTheme.paper)
        }
    }

    private func toggleSelecting() {
        isSelecting.toggle()
        if !isSelecting {
            selectedIds.removeAll()
            isAllSelected = false
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
        isAllSelected = !submissions.isEmpty && selectedIds.count == submissions.count
    }

    private func toggleSelectAll() {
        if isAllSelected {
            selectedIds.removeAll()
            isAllSelected = false
        } else {
            selectedIds = Set(submissions.map { $0.id })
            isAllSelected = true
        }
    }

    private func exportSelected() {
        let picked = submissions.filter { selectedIds.contains($0.id) }
        guard picked.isEmpty == false else { return }

        do {
            let csv = buildCSV(submissions: picked)
            let url = try writeTempCSV(csv: csv, filename: "\(event.title)-访客.csv")
            shareURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildCSV(submissions list: [SubmissionV2]) -> String {
        // Build columns: createdAt, tags, then union of labels in first-seen order.
        var labels: [String] = []
        var labelSet: Set<String> = []

        func addLabel(_ s: String) {
            guard labelSet.contains(s) == false else { return }
            labelSet.insert(s)
            labels.append(s)
        }

        for s in list {
            let pairs = displayPairs(for: s)
            for (label, _) in pairs {
                addLabel(label)
            }
        }

        var rows: [[String]] = []
        let header = ["提交时间", "标签"] + labels
        rows.append(header)

        for s in list {
            let time = s.createdAt?.formatted(date: .numeric, time: .standard) ?? ""
            let tags = (s.tags ?? []).joined(separator: "|")

            var map: [String: String] = [:]
            for (label, value) in displayPairs(for: s) {
                map[label] = value
            }

            var row: [String] = [time, tags]
            row.append(contentsOf: labels.map { map[$0] ?? "" })
            rows.append(row)
        }

        // CSV with Excel-friendly BOM
        let out = rows
            .map { $0.map { csvCell($0) }.joined(separator: ",") }
            .joined(separator: "\n")
        return "\u{FEFF}" + out
    }

    private func csvCell(_ s: String) -> String {
        // Escape double quotes; quote when needed.
        let needsQuote = s.contains(",") || s.contains("\n") || s.contains("\"")
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuote ? "\"\(escaped)\"" : escaped
    }

    private func writeTempCSV(csv: String, filename: String) throws -> URL {
        let safe = filename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safe)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func displayPairs(for submission: SubmissionV2) -> [(String, String)] {
        guard let form = formForSubmission(submission) else { return [] }

        var out: [(String, String)] = []
        for field in form.schema.fields {
            switch field.type {
            case .name:
                let keys = field.nameKeys ?? ["full_name"]
                let parts = keys.compactMap { submission.data[$0]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let value = parts.joined(separator: " ")
                if value.isEmpty == false { out.append((field.label, value)) }

            case .phone:
                if (field.phoneFormat ?? .plain) == .withCountryCode {
                    let keys = field.phoneKeys ?? [field.key]
                    let cc = keys.indices.contains(0) ? (submission.data[keys[0]]?.stringValue ?? "") : ""
                    let num = keys.indices.contains(1) ? (submission.data[keys[1]]?.stringValue ?? "") : ""
                    let value = ([cc, num].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }).joined(separator: " ")
                    if value.isEmpty == false { out.append((field.label, value)) }
                } else {
                    let value = submission.data[field.key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if value.isEmpty == false { out.append((field.label, value)) }
                }

            case .text, .multilineText, .email, .select, .dropdown, .date, .time, .address:
                let value = submission.data[field.key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if value.isEmpty == false { out.append((field.label, value)) }

            case .multiSelect:
                let arr = submission.data[field.key]?.arrayValue ?? []
                let value = arr.compactMap { $0.stringValue }.filter { !$0.isEmpty }.joined(separator: "、")
                if value.isEmpty == false { out.append((field.label, value)) }

            case .checkbox:
                let b = submission.data[field.key]?.boolValue ?? false
                if b {
                    out.append((field.label, "是"))
                }

            case .sectionTitle, .sectionSubtitle, .divider, .splice:
                // Display-only fields: do not appear in submission.data
                break
            }
        }

        return out
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            submissions = try await service.listSubmissions(eventId: event.id)

            // Load forms needed to render submissions using the correct template.
            var ids: Set<UUID> = [event.formId]
            for s in submissions {
                if let fid = s.formId { ids.insert(fid) }
            }

            var map: [UUID: FormRecord] = [:]
            try await withThrowingTaskGroup(of: (UUID, FormRecord).self) { group in
                for id in ids {
                    group.addTask {
                        let f = try await service.getForm(id: id)
                        return (id, f)
                    }
                }

                for try await (id, f) in group {
                    map[id] = f
                }
            }

            formsById = map
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSelected() async {
        guard let s = selectedSubmission else { return }
        isLoading = true
        defer {
            isLoading = false
            selectedSubmission = nil
        }
        do {
            try await service.deleteSubmission(id: s.id)
            submissions.removeAll(where: { $0.id == s.id })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

private struct SubmissionTagPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let service: DynamicFormService
    let submission: SubmissionV2?
    let onSaved: (SubmissionV2) -> Void

    @State private var tags: [OpenHouseTag] = []
    @State private var selected: Set<String> = []

    @State private var newTagName: String = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        EMScreen("标签") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("选择标签", subtitle: "点选标签，也可以创建新标签")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("创建新标签")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)

                                HStack(spacing: 10) {
                                    TextField("例如：意向强", text: $newTagName)
                                        .textFieldStyle(.roundedBorder)

                                    Button(isLoading ? "创建中" : "创建") {
                                        hideKeyboard()
                                        Task { await createTag() }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isLoading || newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }

                            Divider().overlay(EMTheme.line)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("点选标签")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)

                                if tags.isEmpty {
                                    Text("暂无标签")
                                        .font(.callout)
                                        .foregroundStyle(EMTheme.ink2)
                                        .padding(.vertical, 4)
                                } else {
                                    FlowLayout(maxPerRow: 3, spacing: 8) {
                                        ForEach(tags) { t in
                                            Button {
                                                toggle(t.name)
                                            } label: {
                                                EMChip(text: t.name, isOn: selected.contains(t.name))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button(isLoading ? "保存中..." : "保存") {
                        Task { await save() }
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading || submission == nil))
                    .disabled(isLoading || submission == nil)

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
                    .foregroundStyle(EMTheme.ink2)
            }
        }
        .task { await load() }
        .onAppear {
            if let submission {
                selected = Set(submission.tags ?? [])
            }
        }
    }

    private func toggle(_ name: String) {
        if selected.contains(name) {
            selected.remove(name)
        } else {
            selected.insert(name)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            tags = try await service.listTags()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createTag() async {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let created = try await service.createTag(name: name)
            // Put at front
            tags.insert(created, at: 0)
            selected.insert(created.name)
            newTagName = ""
            errorMessage = nil
        } catch {
            // Unique constraint might fail; still refresh list.
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            await load()
        }
    }

    private func save() async {
        guard let submission else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let updated = try await service.updateSubmissionTags(id: submission.id, tags: Array(selected).sorted())
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SubmissionEditView: View {
    @Environment(\.dismiss) private var dismiss

    let service: DynamicFormService
    let form: FormRecord
    let submission: SubmissionV2
    let onSaved: (SubmissionV2) -> Void

    @State private var values: [String: String] = [:]
    @State private var boolValues: [String: Bool] = [:]
    @State private var multiValues: [String: Set<String>] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        EMScreen("编辑") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    EMCard {
                        VStack(spacing: 12) {
                            ForEach(form.schema.fields) { f in
                                fieldRow(f)
                            }
                        }
                    }

                    Button(isSaving ? "保存中..." : "保存") {
                        hideKeyboard()
                        Task { await save() }
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isSaving))
                    .disabled(isSaving)

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
                    .foregroundStyle(EMTheme.ink2)
            }
        }
        .onAppear {
            // Seed editors from JSON payload
            values = [:]
            boolValues = [:]
            multiValues = [:]

            for f in form.schema.fields {
                switch f.type {
                case .checkbox:
                    boolValues[f.key] = submission.data[f.key]?.boolValue ?? false
                case .multiSelect:
                    let arr = submission.data[f.key]?.arrayValue ?? []
                    multiValues[f.key] = Set(arr.compactMap { $0.stringValue })
                case .name:
                    for k in f.nameKeys ?? [] {
                        values[k] = submission.data[k]?.stringValue ?? ""
                    }
                case .phone:
                    if (f.phoneFormat ?? .plain) == .withCountryCode {
                        for k in f.phoneKeys ?? [] {
                            values[k] = submission.data[k]?.stringValue ?? ""
                        }
                    } else {
                        values[f.key] = submission.data[f.key]?.stringValue ?? ""
                    }

                case .sectionTitle, .sectionSubtitle, .divider, .splice:
                    // Display-only fields: nothing to seed.
                    break

                default:
                    values[f.key] = submission.data[f.key]?.stringValue ?? ""
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: FormField) -> some View {
        switch field.type {
        case .name:
            let keys = field.nameKeys ?? ["full_name"]
            if keys.count == 1 {
                EMTextField(title: field.label, text: binding(for: keys[0], field: field))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(field.label)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EMTheme.ink2)

                    HStack(spacing: 12) {
                        if keys.indices.contains(0) {
                            EMInlineTextField(text: binding(for: keys[0], field: field), prompt: "名")
                        }
                        if keys.indices.contains(1) {
                            EMInlineTextField(text: binding(for: keys[1], field: field), prompt: (keys.count == 2 ? "姓" : "中间名"))
                        }
                        if keys.indices.contains(2) {
                            EMInlineTextField(text: binding(for: keys[2], field: field), prompt: "姓")
                        }
                    }
                }
            }

        case .text:
            EMTextField(title: field.label, text: binding(for: field.key, field: field), prompt: field.placeholder ?? "请输入...")

        case .date:
            EMTextField(title: field.label, text: binding(for: field.key, field: field), prompt: "")
                .disabled(!(field.isEditable ?? false))

        case .time:
            EMTextField(title: field.label, text: binding(for: field.key, field: field), prompt: "")
                .disabled(!(field.isEditable ?? false))

        case .address:
            EMTextField(title: field.label, text: binding(for: field.key, field: field), prompt: "")
                .disabled(!(field.isEditable ?? false))

        case .multilineText:
            EMTextArea(title: field.label, text: binding(for: field.key, field: field), prompt: field.placeholder ?? "请输入...", minHeight: 96)

        case .phone:
            let keys = field.phoneKeys ?? [field.key]
            if (field.phoneFormat ?? .plain) == .withCountryCode, keys.count >= 2 {
                EMPhoneWithCountryCodeField(
                    title: field.label,
                    code: binding(for: keys[0], field: field),
                    number: binding(for: keys[1], field: field),
                    prompt: "手机号"
                )
            } else {
                EMTextField(title: field.label, text: binding(for: field.key, field: field), keyboard: .phonePad)
            }

        case .email:
            EMEmailField(title: field.label, text: binding(for: field.key, field: field), prompt: field.placeholder ?? "请输入...")

        case .select:
            if (field.selectStyle ?? .dropdown) == .dot {
                EMSelectDotsField(
                    title: field.label,
                    options: field.options ?? [],
                    selection: binding(for: field.key, field: field)
                )
            } else {
                EMChoiceField(
                    title: field.label,
                    placeholder: field.placeholder ?? "请选择...",
                    options: field.options ?? [],
                    selection: binding(for: field.key, field: field)
                )
            }

        case .dropdown:
            EMChoiceField(
                title: field.label,
                placeholder: field.placeholder ?? "请选择...",
                options: field.options ?? [],
                selection: binding(for: field.key, field: field)
            )

        case .multiSelect:
            EMMultiSelectField(
                title: field.label,
                options: field.options ?? [],
                selection: multiBinding(for: field.key),
                style: field.multiSelectStyle ?? .chips
            )

        case .checkbox:
            Button {
                boolValues[field.key, default: false].toggle()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: boolValues[field.key, default: false] ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(boolValues[field.key, default: false] ? EMTheme.accent : EMTheme.ink2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.label)
                            .font(.callout)
                            .foregroundStyle(EMTheme.ink)

                        // Do NOT trim: subtitle may intentionally contain leading/trailing spaces.
                        if let sub = field.subtitle, sub.isEmpty == false {
                            Text(sub)
                                .font(.caption)
                                .foregroundStyle(EMTheme.ink2)
                        }
                    }

                    Spacer()

                    Text(field.required ? "必填" : "选填")
                        .font(.caption)
                        .foregroundStyle(EMTheme.ink2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .fill(EMTheme.paper2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .stroke(EMTheme.line, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

        case .sectionTitle:
            let size = CGFloat(field.fontSize ?? 22)
            let c = EMTheme.decorationColor(for: field.decorationColorKey ?? EMTheme.DecorationColorKey.default.rawValue) ?? EMTheme.ink
            Text(field.label)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(c)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)

        case .sectionSubtitle:
            let size = CGFloat(field.fontSize ?? 16)
            let c = EMTheme.decorationColor(for: field.decorationColorKey ?? EMTheme.DecorationColorKey.default.rawValue) ?? EMTheme.ink2
            Text(field.label)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(c)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)

        case .divider:
            let c = EMTheme.decorationColor(for: field.decorationColorKey ?? EMTheme.DecorationColorKey.default.rawValue) ?? EMTheme.line
            DividerLineView(
                dashed: field.dividerDashed ?? false,
                thickness: CGFloat(field.dividerThickness ?? 1),
                color: c
            )
            .padding(.vertical, 6)

        case .splice:
            EmptyView()
        }
    }

    private func pickerField(_ field: FormField, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(EMTheme.ink2)

            Picker(title, selection: binding(for: field.key, field: field)) {
                Text("请选择...").tag("")
                ForEach(field.options ?? [], id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .fill(EMTheme.paper2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .stroke(EMTheme.line, lineWidth: 1)
            )
        }
    }

    private func multiBinding(for key: String) -> Binding<Set<String>> {
        Binding(
            get: { multiValues[key, default: []] },
            set: { multiValues[key] = $0 }
        )
    }

    private func toggleMultiSelect(key: String, option: String) {
        var set = multiValues[key, default: []]
        if set.contains(option) {
            set.remove(option)
        } else {
            set.insert(option)
        }
        multiValues[key] = set
    }

    private func binding(for key: String, field: FormField? = nil) -> Binding<String> {
        Binding(
            get: { values[key, default: ""] },
            set: { newValue in
                // 文本大小写转换已移除：保持用户原样输入。
                values[key] = newValue
            }
        )
    }

    private func save() async {
        // Basic email validation
        for f in form.schema.fields where f.type == .email {
            let raw = values[f.key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty == false && isValidEmail(raw) == false {
                errorMessage = "邮箱格式不正确，请检查后再保存"
                return
            }
        }

        isSaving = true
        defer { isSaving = false }

        do {
            var payload: [String: AnyJSON] = [:]

            // Strings
            for (k, v) in values {
                let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty == false {
                    payload[k] = .string(t)
                }
            }

            // Checkbox
            for (k, v) in boolValues {
                payload[k] = .bool(v)
            }

            // Multi select
            for (k, set) in multiValues {
                let arr = set.sorted().map { AnyJSON.string($0) }
                payload[k] = .array(arr)
            }

            let updated = try await service.updateSubmission(id: submission.id, data: payload, tags: submission.tags)
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return s.range(of: pattern, options: .regularExpression) != nil
    }
}

private struct DividerLineView: View {
    let dashed: Bool
    let thickness: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let y = size.height / 2
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: max(1, thickness), lineCap: .round, dash: dashed ? [6, 4] : [])
            )
        }
        .frame(height: max(1, thickness))
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
