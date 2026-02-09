//
//  OpenHouseGuestFlowView.swift
//  EstateMate
//
//  Guest mode flow:
//  1) Pick an event
//  2) Preview its form (full screen) + Start button
//  3) Kiosk filling screen (full screen)
//

import SwiftUI

@available(*, deprecated, message: "Use OpenHouseStartActivityView instead")
struct OpenHouseGuestFlowView: View {
    var body: some View {
        NavigationStack {
            OpenHouseEventPickerView()
        }
    }
}

private struct OpenHouseEventPickerView: View {
    private let service = DynamicFormService()

    @State private var events: [OpenHouseEventV2] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        EMScreen("选择活动") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("选择活动", subtitle: "选择一个活动后开始访客登记")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    EMCard {
                        HStack {
                            Spacer()
                            Button("刷新") { Task { await load() } }
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.accent)
                        }

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        } else if events.isEmpty {
                            Text("暂无活动")
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.vertical, 10)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(events.enumerated()), id: \.element.id) { idx, e in
                                    NavigationLink {
                                        OpenHouseEventPreviewView(event: e)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(e.title)
                                                    .font(.headline)
                                                    .foregroundStyle(EMTheme.ink)
                                                Text(e.isActive ? "已启用" : "未启用")
                                                    .font(.caption)
                                                    .foregroundStyle(e.isActive ? .green : EMTheme.ink2)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(EMTheme.ink2)
                                        }
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)

                                    if idx != events.count - 1 {
                                        Divider().overlay(EMTheme.line)
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
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await service.listEvents()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct OpenHouseEventPreviewView: View {
    private let service = DynamicFormService()

    let event: OpenHouseEventV2

    @State private var form: FormRecord?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showKiosk = false

    @State private var password = ""
    @State private var showSetPassword = false
    @State private var passwordDraft = ""

    var body: some View {
        EMScreen("活动预览") {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        EMSectionHeader(event.title, subtitle: "确认表单后开始活动")

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }

                        if let form {
                            EMCard {
                                Text("表单预览")
                                    .font(.headline)

                                VStack(spacing: 0) {
                                    ForEach(Array(form.schema.fields.enumerated()), id: \.element.id) { idx, f in
                                        HStack {
                                            Text(f.label)
                                                .font(.headline)
                                            Spacer()
                                            Text(fieldTypeName(f))
                                                .font(.caption)
                                                .foregroundStyle(EMTheme.ink2)
                                        }
                                        .padding(.vertical, 10)

                                        if idx != form.schema.fields.count - 1 {
                                            Divider().overlay(EMTheme.line)
                                        }
                                    }
                                }
                            }

                            Button("开始活动") {
                                passwordDraft = ""
                                showSetPassword = true
                            }
                            .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                        } else {
                            EMCard {
                                Text("加载表单中...")
                                    .foregroundStyle(EMTheme.ink2)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(EMTheme.padding)
                }

                if isLoading {
                    ProgressView()
                }
            }
        }
        .task { await load() }
        .alert("设置密码", isPresented: $showSetPassword) {
            SecureField("密码", text: $passwordDraft)
            Button("开始") {
                password = passwordDraft
                passwordDraft = ""
                showKiosk = true
            }
            Button("取消", role: .cancel) {
                passwordDraft = ""
            }
        } message: {
            Text("开始活动前需要输入一个密码。返回或查看已提交列表时也需要此密码。")
        }
        .fullScreenCover(isPresented: $showKiosk) {
            if let form {
                NavigationStack {
                    OpenHouseKioskFillView(event: event, form: form, password: password)
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            form = try await service.getForm(id: event.formId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fieldTypeName(_ f: FormField) -> String {
        switch f.type {
        case .name: return "姓名"
        case .text: return "文本"
        case .phone: return "手机号"
        case .email: return "邮箱"
        case .select: return "单选"
        }
    }
}

struct OpenHouseKioskFillView: View {
    @Environment(\.dismiss) private var dismiss

    private let service = DynamicFormService()

    let event: OpenHouseEventV2
    let form: FormRecord
    let password: String

    @State private var values: [String: String] = [:]
    @State private var submittedCount = 0

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showPasswordCheck = false
    @State private var passwordCheckDraft = ""
    @State private var pendingAction: PendingAction?

    @State private var showSubmissions = false

    private enum PendingAction {
        case back
        case submissions
    }

    var body: some View {
        EMScreen(nil) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(event.title)
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text("已提交：\(submittedCount)")
                            .font(.footnote)
                            .foregroundStyle(EMTheme.ink2)
                    }

                    EMCard {
                        VStack(spacing: 12) {
                            ForEach(form.schema.fields) { field in
                                fieldRow(field)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    Button(isLoading ? "提交中..." : "提交") {
                        Task { await submit(eventId: event.id, form: form) }
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading || !canSubmit(form: form)))
                    .disabled(isLoading || !canSubmit(form: form))

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回") {
                    pendingAction = .back
                    showPasswordCheck = true
                }
                .foregroundStyle(EMTheme.ink2)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    pendingAction = .submissions
                    showPasswordCheck = true
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(EMTheme.ink)
                }
                .accessibilityLabel("已提交列表")
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .alert("输入密码", isPresented: $showPasswordCheck) {
            SecureField("密码", text: $passwordCheckDraft)
            Button("确认") {
                verifyPasswordAndContinue()
            }
            Button("取消", role: .cancel) {
                passwordCheckDraft = ""
                pendingAction = nil
            }
        } message: {
            Text("返回或查看已提交列表需要输入密码。")
        }
        .sheet(isPresented: $showSubmissions) {
            NavigationStack {
                OpenHouseSubmissionsListView(event: event)
            }
        }
    }

    private func verifyPasswordAndContinue() {
        let ok = passwordCheckDraft == password
        passwordCheckDraft = ""

        guard ok else {
            errorMessage = "密码错误"
            pendingAction = nil
            return
        }

        errorMessage = nil
        switch pendingAction {
        case .back:
            pendingAction = nil
            dismiss()
        case .submissions:
            pendingAction = nil
            showSubmissions = true
        case .none:
            break
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
            let keys = field.phoneKeys ?? [field.key]
            if (field.phoneFormat ?? .plain) == .withCountryCode, keys.count >= 2 {
                VStack(alignment: .leading, spacing: 8) {
                    Text(field.label)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EMTheme.ink2)

                    HStack(spacing: 12) {
                        Picker("区号", selection: binding(for: keys[0], field: field)) {
                            Text("+1").tag("+1")
                            Text("+86").tag("+86")
                            Text("+852").tag("+852")
                            Text("+81").tag("+81")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 110, alignment: .leading)

                        TextField("手机号", text: binding(for: keys[1], field: field))
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.phonePad)
                    }
                }
            } else {
                EMTextField(title: field.label, text: binding(for: field.key, field: field), keyboard: .phonePad)
            }

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

    private func canSubmit(form: FormRecord) -> Bool {
        for f in form.schema.fields where f.required {
            if f.type == .name {
                for k in f.nameKeys ?? [] {
                    let v = values[k, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                    if v.isEmpty { return false }
                }
            } else if f.type == .phone, (f.phoneFormat ?? .plain) == .withCountryCode {
                for k in f.phoneKeys ?? [] {
                    let v = values[k, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                    if v.isEmpty { return false }
                }
            } else {
                let v = values[f.key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                if v.isEmpty { return false }
            }
        }
        return true
    }

    private func submit(eventId: UUID, form: FormRecord) async {
        isLoading = true
        defer { isLoading = false }
        do {
            var payload: [String: String] = [:]
            for f in form.schema.fields {
                if f.type == .name {
                    for k in f.nameKeys ?? [] {
                        payload[k] = values[k, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else if f.type == .phone, (f.phoneFormat ?? .plain) == .withCountryCode {
                    for k in f.phoneKeys ?? [] {
                        payload[k] = values[k, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else {
                    payload[f.key] = values[f.key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            _ = try await service.createSubmission(eventId: eventId, data: payload)
            submittedCount += 1
            values = [:]
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
