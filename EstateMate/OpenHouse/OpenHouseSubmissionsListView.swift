//
//  OpenHouseSubmissionsListView.swift
//  EstateMate
//

import SwiftUI

struct OpenHouseSubmissionsListView: View {
    @Environment(\.dismiss) private var dismiss

    private let service = DynamicFormService()

    let event: OpenHouseEventV2

    @State private var form: FormRecord?
    @State private var submissions: [SubmissionV2] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var selectedSubmission: SubmissionV2?
    @State private var showEditSheet = false

    @State private var showDeleteConfirm = false

    @State private var showTagEditor = false
    @State private var tagDraft = ""

    var body: some View {
        EMScreen("已提交") {
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
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(s.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(EMTheme.ink2)

                                        Spacer()

                                        HStack(spacing: 10) {
                                            Button {
                                                selectedSubmission = s
                                                tagDraft = (s.tags ?? []).joined(separator: ", ")
                                                showTagEditor = true
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
                                            .disabled(form == nil)
                                            .opacity(form == nil ? 0.4 : 1)

                                            Button {
                                                selectedSubmission = s
                                                showDeleteConfirm = true
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("删除")
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
                                        ForEach(s.data.keys.sorted(), id: \.self) { k in
                                            HStack(alignment: .firstTextBaseline) {
                                                Text(k)
                                                    .font(.caption)
                                                    .foregroundStyle(EMTheme.ink2)
                                                    .frame(width: 90, alignment: .leading)
                                                Text(s.data[k] ?? "")
                                                    .font(.callout)
                                                    .foregroundStyle(EMTheme.ink)
                                                Spacer(minLength: 0)
                                            }
                                        }
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
                    .foregroundStyle(EMTheme.ink2)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showEditSheet) {
            if let form, let selectedSubmission {
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
        .alert("添加标签", isPresented: $showTagEditor) {
            TextField("例如：意向强, 预算高", text: $tagDraft)
            Button("保存") {
                Task { await saveTags() }
            }
            Button("取消", role: .cancel) {
                tagDraft = ""
                selectedSubmission = nil
            }
        } message: {
            Text("用逗号分隔多个标签")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let submissionsTask = service.listSubmissions(eventId: event.id)
            async let formTask = service.getForm(id: event.formId)
            submissions = try await submissionsTask
            form = try? await formTask
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

    private func saveTags() async {
        guard let s = selectedSubmission else { return }
        let tags = parseTags(tagDraft)

        isLoading = true
        defer {
            isLoading = false
            tagDraft = ""
            selectedSubmission = nil
        }

        do {
            let updated = try await service.updateSubmissionTags(id: s.id, tags: tags)
            if let idx = submissions.firstIndex(where: { $0.id == updated.id }) {
                submissions[idx] = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseTags(_ input: String) -> [String] {
        input
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct SubmissionEditView: View {
    @Environment(\.dismiss) private var dismiss

    let service: DynamicFormService
    let form: FormRecord
    let submission: SubmissionV2
    let onSaved: (SubmissionV2) -> Void

    @State private var values: [String: String] = [:]
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
            values = submission.data
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
                            TextField("名", text: binding(for: keys[0], field: field))
                                .textFieldStyle(.roundedBorder)
                        }
                        if keys.indices.contains(1) {
                            TextField(keys.count == 2 ? "姓" : "中间名", text: binding(for: keys[1], field: field))
                                .textFieldStyle(.roundedBorder)
                        }
                        if keys.indices.contains(2) {
                            TextField("姓", text: binding(for: keys[2], field: field))
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

        case .text:
            EMTextField(title: field.label, text: binding(for: field.key, field: field))

        case .phone:
            EMTextField(title: field.label, text: binding(for: field.key, field: field), keyboard: .phonePad)

        case .email:
            EMTextField(title: field.label, text: binding(for: field.key, field: field), keyboard: .emailAddress)

        case .select:
            VStack(alignment: .leading, spacing: 8) {
                Text(field.label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)

                Picker("请选择", selection: binding(for: field.key, field: field)) {
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
    }

    private func binding(for key: String, field: FormField? = nil) -> Binding<String> {
        Binding(
            get: { values[key, default: ""] },
            set: { newValue in
                if let field, field.type == .text {
                    switch field.textCase ?? .none {
                    case .none:
                        values[key] = newValue
                    case .upper:
                        values[key] = newValue.uppercased()
                    case .lower:
                        values[key] = newValue.lowercased()
                    }
                } else {
                    values[key] = newValue
                }
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
            // Trim all values
            var trimmed: [String: String] = [:]
            for (k, v) in values {
                let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty == false {
                    trimmed[k] = t
                }
            }

            let updated = try await service.updateSubmission(id: submission.id, data: trimmed, tags: submission.tags)
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
