//
//  OpenHouseGuestModeV2View.swift
//  EstateMate
//
//  Dynamic guest mode based on FormSchema.
//

import SwiftUI
import Supabase

struct OpenHouseGuestModeV2View: View {
    private let service = DynamicFormService()

    @State private var activeEvent: OpenHouseEventV2?
    @State private var activeForm: FormRecord?

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var values: [String: String] = [:]
    @State private var boolValues: [String: Bool] = [:]
    @State private var multiValues: [String: Set<String>] = [:]
    @State private var submittedCount = 0

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView().controlSize(.large)
            }

            if let event = activeEvent, let form = activeForm {
                Text(event.title)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Form {
                    Section(form.name) {
                                ForEach(form.schema.fields) { field in
                            fieldRow(field)
                        }
                    }

                    Section {
                        Button("提交") {
                            Task { await submit(eventId: event.id, form: form) }
                        }
                        .disabled(!canSubmit(form: form) || isLoading)

                        if submittedCount > 0 {
                            Text("已提交：\(submittedCount)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("没有启用的活动")
                        .font(.title3.bold())
                    Text("请先在“活动管理”里创建活动并设为启用。")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("访客模式")
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新") { Task { await load() } }
            }
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

        case .multilineText:
            VStack(alignment: .leading, spacing: 8) {
                Text(field.label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)
                TextEditor(text: binding(for: field.key, field: field))
                    .frame(minHeight: 110)
            }

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

        case .dropdown:
            Picker(field.label, selection: binding(for: field.key, field: field)) {
                Text("下拉选择...").tag("")
                ForEach(field.options ?? [], id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }

        case .multiSelect:
            VStack(alignment: .leading, spacing: 8) {
                Text(field.label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)

                FlowLayout(maxPerRow: 3, spacing: 8) {
                    ForEach(field.options ?? [], id: \.self) { opt in
                        let isOn = multiValues[field.key, default: []].contains(opt)
                        Button {
                            toggleMultiSelect(key: field.key, option: opt)
                        } label: {
                            EMChip(text: opt, isOn: isOn)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case .checkbox:
            Button {
                boolValues[field.key, default: false].toggle()
            } label: {
                HStack {
                    Image(systemName: boolValues[field.key, default: false] ? "checkmark.square.fill" : "square")
                    Text(field.label)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

        case .sectionTitle:
            Text(field.label)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

        case .sectionSubtitle:
            Text(field.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .divider:
            Divider()

        case .splice:
            EmptyView()
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

    private func toggleMultiSelect(key: String, option: String) {
        var set = multiValues[key, default: []]
        if set.contains(option) {
            set.remove(option)
        } else {
            set.insert(option)
        }
        multiValues[key] = set
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let event = try await service.getActiveEvent()
            self.activeEvent = event

            if let event {
                self.activeForm = try await service.getForm(id: event.formId)
            } else {
                self.activeForm = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
                switch f.type {
                case .checkbox:
                    if boolValues[f.key, default: false] == false { return false }
                case .multiSelect:
                    if multiValues[f.key, default: []].isEmpty { return false }
                default:
                    let v = values[f.key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                    if v.isEmpty { return false }
                }
            }
        }
        return true
    }

    private func submit(eventId: UUID, form: FormRecord) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Only keep keys from schema to avoid junk
            var payload: [String: AnyJSON] = [:]
            for f in form.schema.fields {
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

            _ = try await service.createSubmission(eventId: eventId, data: payload)
            submittedCount += 1
            values = [:]
            boolValues = [:]
            multiValues = [:]
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { OpenHouseGuestModeV2View() }
}
