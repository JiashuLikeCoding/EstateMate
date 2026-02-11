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

    @State private var templates: [EmailTemplateRecord] = []
    @State private var selectedEmailTemplateId: UUID?
    @State private var isEmailTemplateSheetPresented: Bool = false

    var body: some View {
        List {
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section("创建活动") {
                TextField("活动标题（例如：123 Main St - 2月10日）", text: $newTitle)

                Picker("选择表单", selection: $selectedFormId) {
                    Text("请选择...").tag(Optional<UUID>.none)
                    ForEach(forms) { f in
                        Text(f.name).tag(Optional(f.id))
                    }
                }

                Button("绑定邮件模版（可选）") {
                    isEmailTemplateSheetPresented = true
                }

                Button("创建") {
                    Task { await createEvent() }
                }
                .disabled(
                    newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    selectedFormId == nil ||
                    isLoading
                )

                NavigationLink("去创建新表单") {
                    FormBuilderAdaptiveView()
                }
            }

            Section("活动列表") {
                if events.isEmpty {
                    Text("暂无活动").foregroundStyle(.secondary)
                } else {
                    ForEach(events) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.title)
                                Text(e.isActive ? "已启用" : "未启用")
                                    .font(.caption)
                                    .foregroundStyle(e.isActive ? .green : .secondary)
                            }
                            Spacer()
                            if !e.isActive {
                                Button("设为启用") {
                                    Task { await makeActive(e) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("活动管理")
        .overlay {
            if isLoading { ProgressView().controlSize(.large) }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $isEmailTemplateSheetPresented) {
            NavigationStack {
                EmailTemplateSelectView(workspace: .openhouse, selectedTemplateId: $selectedEmailTemplateId)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            forms = try await service.listForms()
            events = try await service.listEvents()
            templates = try await EmailTemplateService().listTemplates(workspace: nil)
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
                location: nil,
                startsAt: nil,
                endsAt: nil,
                host: nil,
                assistant: nil,
                formId: formId,
                emailTemplateId: selectedEmailTemplateId,
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
