//
//  OpenHouseGuestModeV2View.swift
//  EstateMate
//
//  Dynamic guest mode based on FormSchema.
//

import SwiftUI

struct OpenHouseGuestModeV2View: View {
    private let service = DynamicFormService()

    @State private var activeEvent: OpenHouseEventV2?
    @State private var activeForm: FormRecord?

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var values: [String: String] = [:]
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
                        Button("Submit") {
                            Task { await submit(eventId: event.id, form: form) }
                        }
                        .disabled(!canSubmit(form: form) || isLoading)

                        if submittedCount > 0 {
                            Text("Submitted: \(submittedCount)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No active event")
                        .font(.title3.bold())
                    Text("Create an event and set it active.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Guest Mode")
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reload") { Task { await load() } }
            }
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: FormField) -> some View {
        switch field.type {
        case .text:
            TextField(field.label, text: binding(for: field.key))
        case .phone:
            TextField(field.label, text: binding(for: field.key))
                .keyboardType(.phonePad)
        case .email:
            TextField(field.label, text: binding(for: field.key))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        case .select:
            Picker(field.label, selection: binding(for: field.key)) {
                Text("Select...").tag("")
                ForEach(field.options ?? [], id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { values[key, default: ""] },
            set: { values[key] = $0 }
        )
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
            let v = values[f.key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            if v.isEmpty { return false }
        }
        return true
    }

    private func submit(eventId: UUID, form: FormRecord) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Only keep keys from schema to avoid junk
            var payload: [String: String] = [:]
            for f in form.schema.fields {
                payload[f.key] = values[f.key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
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

#Preview {
    NavigationStack { OpenHouseGuestModeV2View() }
}
