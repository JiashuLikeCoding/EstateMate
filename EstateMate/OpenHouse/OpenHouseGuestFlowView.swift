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
import Supabase

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
        case .multilineText: return "多行文本"
        case .phone: return "手机号"
        case .email: return "邮箱"
        case .select: return "单选"
        case .dropdown: return "下拉选框"
        case .multiSelect: return "多选"
        case .checkbox: return "勾选"
        case .sectionTitle: return "大标题"
        case .sectionSubtitle: return "小标题"
        case .divider: return "分割线"
        case .splice: return "拼接"
        }
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

struct OpenHouseKioskFillView: View {
    @Environment(\.dismiss) private var dismiss

    private let service = DynamicFormService()

    let event: OpenHouseEventV2
    let form: FormRecord
    let password: String

    @State private var values: [String: String] = [:]
    @State private var boolValues: [String: Bool] = [:]
    @State private var multiValues: [String: Set<String>] = [:]
    // Note: do not show submitted count in the filling screen UI.
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var submittedCount = 0

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showThankYou = false
    @State private var thankYouMessage = "感谢您的填写！"

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
            ZStack {
                if let bg = form.schema.presentation?.background {
                    EMFormBackgroundView(background: bg)
                        .ignoresSafeArea()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Title is in navigation bar (center). Do not show submitted count here.
                        EmptyView()
                            .frame(height: 0)

                        EMCard {
                            VStack(spacing: 12) {
                                ForEach(fieldRows(form.schema.fields), id: \.self) { row in
                                    if row.count <= 1 || hSizeClass != .regular {
                                        if let f = row.first {
                                            fieldRow(f, reserveTitleSpace: false)
                                        }
                                    } else {
                                        HStack(alignment: .top, spacing: 12) {
                                            ForEach(row) { f in
                                                fieldRow(f, reserveTitleSpace: true)
                                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    Button(isLoading ? "提交中..." : "提交") {
                        hideKeyboard()
                        Task { await submit(eventId: event.id, form: form) }
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading || !canSubmit(form: form)))
                    .disabled(isLoading || !canSubmit(form: form))

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
                }
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

            ToolbarItem(placement: .principal) {
                Text(event.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(EMTheme.ink)
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
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView()
            }

            if showThankYou {
                ZStack {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        Text("已提交")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(EMTheme.ink)

                        Text(thankYouMessage)
                            .font(.callout)
                            .foregroundStyle(EMTheme.ink2)

                        Button("确认") {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showThankYou = false
                            }
                        }
                        .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: 280)
                    .background(
                        RoundedRectangle(cornerRadius: EMTheme.radius, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EMTheme.radius, style: .continuous)
                            .stroke(EMTheme.line, lineWidth: 1)
                    )
                }
                .transition(.opacity)
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
    private func fieldRow(_ field: FormField, reserveTitleSpace: Bool) -> some View {
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
            EMTextField(title: field.label, text: binding(for: field.key, field: field))

        case .multilineText:
            EMTextArea(title: field.label, text: binding(for: field.key, field: field), prompt: "请输入...", minHeight: 96)

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
            EMEmailField(title: field.label, text: binding(for: field.key, field: field), prompt: "请输入...")

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
                    placeholder: "请选择...",
                    options: field.options ?? [],
                    selection: binding(for: field.key, field: field)
                )
            }

        case .dropdown:
            EMChoiceField(
                title: field.label,
                placeholder: "请选择...",
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
            VStack(alignment: .leading, spacing: 8) {
                if reserveTitleSpace {
                    // Reserve the same vertical rhythm as fields that have a title above the input.
                    Text(" ")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.clear)
                }

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

                            if let sub = field.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), sub.isEmpty == false {
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
            }

        case .sectionTitle:
            let size = CGFloat(field.fontSize ?? 22)
            let c = EMTheme.decorationColor(for: field.decorationColorKey ?? EMTheme.DecorationColorKey.default.rawValue) ?? EMTheme.ink
            Text(field.label)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(c)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)

        case .sectionSubtitle:
            let size = CGFloat(field.fontSize ?? 16)
            let c = EMTheme.decorationColor(for: field.decorationColorKey ?? EMTheme.DecorationColorKey.default.rawValue) ?? EMTheme.ink2
            Text(field.label)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(c)
                .frame(maxWidth: .infinity, alignment: .leading)

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

    private func fieldRows(_ fields: [FormField]) -> [[FormField]] {
        // Splice is a marker between fields. Pattern:
        // field, splice, field  -> same row (2)
        // field, splice, field, splice, field -> same row (3)
        // Max 4 fields per row.
        var rows: [[FormField]] = []
        var i = 0

        func isSplice(_ f: FormField) -> Bool { f.type == .splice }

        while i < fields.count {
            let current = fields[i]

            if isSplice(current) {
                // Ignore stray splice.
                i += 1
                continue
            }

            // Decoration rows stay single.
            if current.type == .sectionTitle || current.type == .sectionSubtitle || current.type == .divider {
                rows.append([current])
                i += 1
                continue
            }

            // Start a row with a real input field.
            var row: [FormField] = [current]
            var j = i

            while row.count < 4 {
                let spliceIndex = j + 1
                let nextFieldIndex = j + 2
                guard spliceIndex < fields.count, nextFieldIndex < fields.count else { break }

                if isSplice(fields[spliceIndex]) {
                    let candidate = fields[nextFieldIndex]
                    // Do not join across decoration fields.
                    if candidate.type == .sectionTitle || candidate.type == .sectionSubtitle || candidate.type == .divider || candidate.type == .splice {
                        break
                    }
                    row.append(candidate)
                    j = nextFieldIndex
                } else {
                    break
                }
            }

            rows.append(row)
            i = j + 1
        }

        return rows
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

    private func canSubmit(form: FormRecord) -> Bool {
        for f in form.schema.fields where f.required {
            // Decoration fields are never required.
            if f.type == .sectionTitle || f.type == .sectionSubtitle || f.type == .divider {
                continue
            }
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
                switch f.type {
                case .checkbox:
                    if boolValues[f.key, default: false] == false { return false }
                case .multiSelect:
                    if multiValues[f.key, default: []].isEmpty { return false }
                case .splice, .sectionTitle, .sectionSubtitle, .divider:
                    // Never required.
                    break
                default:
                    let v = values[f.key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                    if v.isEmpty { return false }
                }
            }
        }
        return true
    }

    private func submit(eventId: UUID, form: FormRecord) async {
        // Email format validation: if user typed something, it must look like an email.
        if let msg = validateEmailFields(form: form) {
            errorMessage = msg
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            var payload: [String: AnyJSON] = [:]
            for f in form.schema.fields {
                // Decoration fields are display-only.
                if f.type == .sectionTitle || f.type == .sectionSubtitle || f.type == .divider || f.type == .splice {
                    continue
                }

                if f.type == .name {
                    for k in f.nameKeys ?? [] {
                        payload[k] = .string(values[k, default: ""].trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                } else if f.type == .phone, (f.phoneFormat ?? .plain) == .withCountryCode {
                    for k in f.phoneKeys ?? [] {
                        payload[k] = .string(values[k, default: ""].trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                } else {
                    switch f.type {
                    case .checkbox:
                        payload[f.key] = .bool(boolValues[f.key, default: false])
                    case .multiSelect:
                        let arr = multiValues[f.key, default: []].sorted().map { AnyJSON.string($0) }
                        payload[f.key] = .array(arr)
                    default:
                        payload[f.key] = .string(values[f.key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }

            _ = try await service.createSubmission(eventId: eventId, formId: event.formId, data: payload)
            submittedCount += 1
            values = [:]
            boolValues = [:]
            multiValues = [:]
            errorMessage = nil

            withAnimation(.easeOut(duration: 0.18)) {
                showThankYou = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateEmailFields(form: FormRecord) -> String? {
        for f in form.schema.fields where f.type == .email {
            let raw = values[f.key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            guard raw.isEmpty == false else { continue }
            if isValidEmail(raw) == false {
                return "邮箱格式不正确，请检查后再提交"
            }
        }
        return nil
    }

    private func isValidEmail(_ s: String) -> Bool {
        // Simple, practical email check (not fully RFC-complete, but good UX).
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return s.range(of: pattern, options: .regularExpression) != nil
    }
}
