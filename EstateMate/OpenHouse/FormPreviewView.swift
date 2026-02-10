//
//  FormPreviewView.swift
//  EstateMate
//
//  One-tap preview for Form Builder.
//  Shows the guest/kiosk filling experience without requiring an active event.
//

import SwiftUI

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

struct FormPreviewView: View {
    let formName: String
    let fields: [FormField]
    let presentation: FormPresentation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var values: [String: String] = [:]
    @State private var boolValues: [String: Bool] = [:]
    @State private var multiValues: [String: Set<String>] = [:]

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    @State private var showThankYou = false

    var body: some View {
        EMScreen(nil) {
            ZStack {
                if let bg = presentation.background {
                    EMFormBackgroundView(background: bg)
                        .ignoresSafeArea()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        EMCard {
                            VStack(spacing: 12) {
                                if fields.isEmpty {
                                    Text("当前表单还没有字段")
                                        .foregroundStyle(EMTheme.ink2)
                                } else {
                                    ForEach(fieldRows(fields), id: \.self) { row in
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
                        }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    Button(isSubmitting ? "提交中..." : "提交") {
                        hideKeyboard()
                        submitPreview()
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isSubmitting || !canSubmit()))
                    .disabled(isSubmitting || !canSubmit())

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回") { dismiss() }
                    .foregroundStyle(EMTheme.ink2)
            }

            ToolbarItem(placement: .principal) {
                Text(formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "预览" : formName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(EMTheme.ink)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isSubmitting {
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

                        Text("这只是预览，不会写入数据库。")
                            .font(.callout)
                            .foregroundStyle(EMTheme.ink2)
                            .multilineTextAlignment(.center)

                        Button("确认") {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showThankYou = false
                            }
                            values = [:]
                            boolValues = [:]
                            multiValues = [:]
                            errorMessage = nil
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
            EMTextField(title: field.label, text: binding(for: field.key, field: field), prompt: "请输入...")

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
                EMTextField(title: field.label, text: binding(for: field.key, field: field), prompt: "请输入...", keyboard: .phonePad)
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

                        Text(field.label)
                            .font(.callout)
                            .foregroundStyle(EMTheme.ink)

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

    private func fieldRows(_ fields: [FormField]) -> [[FormField]] {
        var rows: [[FormField]] = []
        var i = 0

        func isSplice(_ f: FormField) -> Bool { f.type == .splice }

        while i < fields.count {
            let current = fields[i]
            if isSplice(current) {
                i += 1
                continue
            }

            if current.type == .sectionTitle || current.type == .sectionSubtitle || current.type == .divider {
                rows.append([current])
                i += 1
                continue
            }

            var row: [FormField] = [current]
            var j = i
            while row.count < 4 {
                let spliceIndex = j + 1
                let nextFieldIndex = j + 2
                guard spliceIndex < fields.count, nextFieldIndex < fields.count else { break }
                if isSplice(fields[spliceIndex]) {
                    let candidate = fields[nextFieldIndex]
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

    private func binding(for key: String, field: FormField? = nil) -> Binding<String> {
        Binding(
            get: { values[key, default: ""] },
            set: { newValue in
                // 文本大小写转换已移除：保持用户原样输入。
                values[key] = newValue
            }
        )
    }

    private func multiBinding(for key: String) -> Binding<Set<String>> {
        Binding(
            get: { multiValues[key, default: []] },
            set: { multiValues[key] = $0 }
        )
    }

    private func requiredKeys(for field: FormField) -> [String] {
        switch field.type {
        case .name:
            return field.nameKeys ?? ["full_name"]
        case .phone:
            if (field.phoneFormat ?? .plain) == .withCountryCode {
                return field.phoneKeys ?? [field.key]
            }
            return [field.key]
        default:
            return [field.key]
        }
    }

    private func canSubmit() -> Bool {
        for f in fields where f.required {
            switch f.type {
            case .checkbox:
                if boolValues[f.key, default: false] == false { return false }
            case .multiSelect:
                if multiValues[f.key, default: []].isEmpty { return false }
            default:
                for k in requiredKeys(for: f) {
                    let v = values[k, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                    if v.isEmpty { return false }
                }
            }
        }
        return true
    }

    private func submitPreview() {
        guard canSubmit() else {
            errorMessage = "请先填写所有必填项"
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        errorMessage = nil
        withAnimation(.easeOut(duration: 0.18)) {
            showThankYou = true
        }
    }
}

#Preview {
    NavigationStack {
        FormPreviewView(
            formName: "到访登记",
            fields: [
                .init(key: "name", label: "姓名", type: .name, required: true, options: nil, textCase: nil, nameFormat: .firstLast, nameKeys: ["first_name", "last_name"], phoneFormat: nil, phoneKeys: nil),
                .init(key: "email", label: "邮箱", type: .email, required: false, options: nil, textCase: nil, nameFormat: nil, nameKeys: nil, phoneFormat: nil, phoneKeys: nil),
                .init(key: "phone", label: "手机号", type: .phone, required: false, options: nil, textCase: nil, nameFormat: nil, nameKeys: nil, phoneFormat: .plain, phoneKeys: ["phone"])
            ],
            presentation: .init(background: .default)
        )
    }
}
