//
//  FormBuilderView.swift
//  EstateMate
//
//  Minimal MVP form builder: add fields (text/phone/email/select) and save schema.
//

import SwiftUI

struct FormBuilderView: View {
    private let service = DynamicFormService()

    @State private var formName: String = ""
    @State private var fields: [FormField] = [
        .init(key: "full_name", label: "Full Name", type: .name, required: false, options: nil, textCase: nil, nameFormat: .fullName, nameKeys: ["full_name"], phoneFormat: nil, phoneKeys: nil),
        .init(key: "phone", label: "Phone", type: .phone, required: false, options: nil, textCase: nil, nameFormat: nil, nameKeys: nil, phoneFormat: .plain, phoneKeys: ["phone"]),
        .init(key: "email", label: "Email", type: .email, required: false, options: nil, textCase: nil, nameFormat: nil, nameKeys: nil, phoneFormat: nil, phoneKeys: nil)
    ]

    @State private var errorMessage: String?
    @State private var isSaving = false

    // New field
    @State private var newLabel: String = ""
    @State private var newType: FormFieldType = .text
    @State private var newRequired: Bool = false
    @State private var newOptionsText: String = "" // comma-separated

    var body: some View {
        List {
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section("表单") {
                TextField("表单名称", text: $formName)
            }

            Section("字段（可拖动排序）") {
                ForEach($fields) { $f in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            TextField("字段标题", text: $f.label)

                            Spacer()

                            Picker("类型", selection: $f.type) {
                                Text("text").tag(FormFieldType.text)
                                Text("phone").tag(FormFieldType.phone)
                                Text("email").tag(FormFieldType.email)
                                Text("select").tag(FormFieldType.select)
                            }
                            .pickerStyle(.menu)
                        }

                        Toggle("必填", isOn: $f.required)

                        if f.type == .select {
                            TextField(
                                "选项（用逗号分隔）",
                                text: Binding(
                                    get: { (f.options ?? []).joined(separator: ",") },
                                    set: { newValue in
                                        let opts = newValue
                                            .split(separator: ",")
                                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                            .filter { !$0.isEmpty }
                                        f.options = opts
                                    }
                                )
                            )
                        }

                        Text("key: \(f.key)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { idxSet in
                    fields.remove(atOffsets: idxSet)
                }
                .onMove { from, to in
                    fields.move(fromOffsets: from, toOffset: to)
                }
            }

            Section("新增字段") {
                TextField("字段名称（例如：预算）", text: $newLabel)

                Picker("类型", selection: $newType) {
                    Text("text").tag(FormFieldType.text)
                    Text("phone").tag(FormFieldType.phone)
                    Text("email").tag(FormFieldType.email)
                    Text("select").tag(FormFieldType.select)
                }

                Toggle("必填", isOn: $newRequired)

                if newType == .select {
                    TextField("选项（用逗号分隔）", text: $newOptionsText)
                }

                Button("添加") {
                    addField()
                }
                .disabled(newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section {
                Button(isSaving ? "保存中..." : "保存表单") {
                    Task { await save() }
                }
                .disabled(isSaving || formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("表单设计")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    private func addField() {
        let label = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = label
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: "__", with: "_")

        let options: [String]?
        if newType == .select {
            let opts = newOptionsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            options = opts.isEmpty ? nil : opts
        } else {
            options = nil
        }

        fields.append(.init(
            key: key,
            label: label,
            type: newType,
            required: newRequired,
            options: options,
            textCase: newType == .text ? .none : nil,
            nameFormat: newType == .name ? .fullName : nil,
            nameKeys: newType == .name ? ["full_name"] : nil,
            phoneFormat: newType == .phone ? .plain : nil,
            phoneKeys: newType == .phone ? ["phone"] : nil
        ))

        newLabel = ""
        newType = .text
        newRequired = false
        newOptionsText = ""
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            // Basic validation for select fields
            for f in fields where f.type == .select {
                if (f.options ?? []).isEmpty {
                    throw NSError(domain: "FormBuilder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Select field '" + f.label + "' needs options."])
                }
            }

            let schema = FormSchema(version: 1, fields: fields)
            _ = try await service.createForm(name: formName, schema: schema)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { FormBuilderView() }
}
