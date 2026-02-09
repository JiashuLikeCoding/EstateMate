//
//  FormPreviewView.swift
//  EstateMate
//
//  One-tap preview for Form Builder.
//  Shows the guest/kiosk filling experience without requiring an active event.
//

import SwiftUI

struct FormPreviewView: View {
    let formName: String
    let fields: [FormField]

    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: String] = [:]
    @State private var showSubmittedAlert = false
    @State private var errorMessage: String? = nil

    var body: some View {
        EMScreen("预览") {
            VStack(spacing: 12) {
                if !formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(formName)
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, EMTheme.padding)
                        .padding(.top, 8)
                }

                Form {
                    Section {
                        if fields.isEmpty {
                            Text("当前表单还没有字段")
                                .foregroundStyle(EMTheme.ink2)
                        } else {
                            ForEach(fields) { field in
                                fieldRow(field)
                            }
                        }
                    } header: {
                        Text("填写示例")
                    }

                    Section {
                        Button("提交（预览）") {
                            submitPreview()
                        }
                        .disabled(!canSubmit())

                        Button("清空") {
                            values = [:]
                            errorMessage = nil
                        }
                        .foregroundStyle(EMTheme.ink2)
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
                    .foregroundStyle(EMTheme.ink2)
            }
        }
        .alert("预览提交", isPresented: $showSubmittedAlert) {
            Button("好的") {
                values = [:]
                errorMessage = nil
            }
        } message: {
            Text("这只是预览，不会写入数据库。")
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: FormField) -> some View {
        switch field.type {
        case .name:
            let keys = field.nameKeys ?? ["full_name"]
            if keys.count == 1 {
                TextField(field.label, text: binding(for: keys[0], field: field))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(field.label)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EMTheme.ink2)

                    HStack(spacing: 12) {
                        if keys.indices.contains(0) {
                            TextField("名", text: binding(for: keys[0], field: field))
                        }
                        if keys.indices.contains(1) {
                            TextField(keys.count == 2 ? "姓" : "中间名", text: binding(for: keys[1], field: field))
                        }
                        if keys.indices.contains(2) {
                            TextField("姓", text: binding(for: keys[2], field: field))
                        }
                    }
                }
            }

        case .text:
            TextField(field.label, text: binding(for: field.key, field: field))

        case .phone:
            let keys = field.phoneKeys ?? [field.key]
            if (field.phoneFormat ?? .plain) == .withCountryCode, keys.count >= 2 {
                VStack(alignment: .leading, spacing: 10) {
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
                            .keyboardType(.phonePad)
                    }
                }
            } else {
                TextField(field.label, text: binding(for: field.key, field: field))
                    .keyboardType(.phonePad)
            }

        case .email:
            TextField(field.label, text: binding(for: field.key, field: field))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

        case .select:
            Picker(field.label, selection: binding(for: field.key, field: field)) {
                Text("请选择...").tag("")
                ForEach(field.options ?? [], id: \.self) { opt in
                    Text(opt).tag(opt)
                }
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
            for k in requiredKeys(for: f) {
                let v = values[k, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                if v.isEmpty { return false }
            }
        }
        return true
    }

    private func submitPreview() {
        guard canSubmit() else {
            errorMessage = "请先填写所有必填项"
            return
        }
        showSubmittedAlert = true
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
            ]
        )
    }
}
