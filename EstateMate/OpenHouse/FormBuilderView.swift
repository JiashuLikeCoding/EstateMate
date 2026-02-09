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
        .init(key: "full_name", label: "Full Name", type: .text, required: true, options: nil),
        .init(key: "phone", label: "Phone", type: .phone, required: true, options: nil),
        .init(key: "email", label: "Email", type: .email, required: false, options: nil)
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

            Section("Form") {
                TextField("Form name", text: $formName)
            }

            Section("Fields") {
                ForEach(fields) { f in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(f.label)
                        Text("key: \(f.key) • type: \(f.type.rawValue) • \(f.required ? "required" : "optional")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if f.type == .select, let opts = f.options {
                            Text("options: \(opts.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idxSet in
                    fields.remove(atOffsets: idxSet)
                }
            }

            Section("Add field") {
                TextField("Label (e.g., Budget)", text: $newLabel)

                Picker("Type", selection: $newType) {
                    ForEach(FormFieldType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }

                Toggle("Required", isOn: $newRequired)

                if newType == .select {
                    TextField("Options (comma separated)", text: $newOptionsText)
                }

                Button("Add") {
                    addField()
                }
                .disabled(newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section {
                Button(isSaving ? "Saving..." : "Save form") {
                    Task { await save() }
                }
                .disabled(isSaving || formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Form Builder")
    }

    private func addField() {
        let label = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = label
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

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

        fields.append(.init(key: key, label: label, type: newType, required: newRequired, options: options))

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
