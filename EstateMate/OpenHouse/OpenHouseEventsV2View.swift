//
//  OpenHouseEventsV2View.swift
//  EstateMate
//
//  Create events and bind a dynamic form.
//

import SwiftUI

struct OpenHouseEventsV2View: View {
    private let service = DynamicFormService()

    @State private var forms: [FormRecord] = []
    @State private var events: [OpenHouseEventV2] = []

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var newTitle: String = ""
    @State private var selectedFormId: UUID?

    var body: some View {
        List {
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section("Create") {
                TextField("Event title", text: $newTitle)

                Picker("Form", selection: $selectedFormId) {
                    Text("Select a form...").tag(Optional<UUID>.none)
                    ForEach(forms) { f in
                        Text(f.name).tag(Optional(f.id))
                    }
                }

                Button("Create Event") {
                    Task { await createEvent() }
                }
                .disabled(
                    newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    selectedFormId == nil ||
                    isLoading
                )

                NavigationLink("Create a new form") {
                    FormBuilderView()
                }
            }

            Section("Events") {
                if events.isEmpty {
                    Text("No events yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(events) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.title)
                                Text(e.isActive ? "Active" : "Inactive")
                                    .font(.caption)
                                    .foregroundStyle(e.isActive ? .green : .secondary)
                            }
                            Spacer()
                            if !e.isActive {
                                Button("Make Active") {
                                    Task { await makeActive(e) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Events")
        .overlay {
            if isLoading { ProgressView().controlSize(.large) }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            forms = try await service.listForms()
            events = try await service.listEvents()
            if selectedFormId == nil {
                selectedFormId = forms.first?.id
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createEvent() async {
        guard let formId = selectedFormId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await service.createEvent(
                title: newTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                formId: formId,
                isActive: events.isEmpty
            )
            newTitle = ""
            events = try await service.listEvents()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeActive(_ event: OpenHouseEventV2) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.setActive(eventId: event.id)
            events = try await service.listEvents()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { OpenHouseEventsV2View() }
}
