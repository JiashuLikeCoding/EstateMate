//
//  OpenHouseEventEditView.swift
//  EstateMate
//

import SwiftUI

struct OpenHouseEventEditView: View {
    @Environment(\.dismiss) private var dismiss

    private let service = DynamicFormService()

    let event: OpenHouseEventV2

    @State private var title: String
    @State private var location: String
    @State private var startsAt: Date
    @State private var endsAt: Date
    @State private var host: String
    @State private var assistant: String

    @State private var forms: [FormRecord] = []
    @State private var selectedFormId: UUID?

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showSaved = false

    init(event: OpenHouseEventV2) {
        self.event = event
        _title = State(initialValue: event.title)
        _location = State(initialValue: event.location ?? "")
        let start = event.startsAt ?? Date()
        _startsAt = State(initialValue: start)
        _endsAt = State(initialValue: event.endsAt ?? Calendar.current.date(byAdding: .hour, value: 2, to: start) ?? start)
        _host = State(initialValue: event.host ?? "")
        _assistant = State(initialValue: event.assistant ?? "")
        _selectedFormId = State(initialValue: event.formId)
    }

    var body: some View {
        EMScreen("编辑活动") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("编辑活动", subtitle: "修改标题、绑定表单、设置启用")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    EMCard {
                        EMTextField(title: "活动标题", text: $title, prompt: "例如：123 Main St - 2月10日")
                        EMTextField(title: "活动地点", text: $location, prompt: "例如：123 Main St, Toronto")

                        DatePicker("开始时间", selection: $startsAt)
                            .datePickerStyle(.compact)

                        DatePicker("结束时间", selection: $endsAt)
                            .datePickerStyle(.compact)

                        EMTextField(title: "主理人", text: $host, prompt: "例如：嘉树")
                        EMTextField(title: "助手", text: $assistant, prompt: "例如：Jason")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("绑定表单")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            Picker("选择表单", selection: $selectedFormId) {
                                Text("请选择...").tag(Optional<UUID>.none)
                                ForEach(forms) { f in
                                    Text(f.name).tag(Optional(f.id))
                                }
                            }
                        }

                        Button(isLoading ? "保存中..." : "保存修改") {
                            Task { await save() }
                        }
                        .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading || !canSave))
                        .disabled(isLoading || !canSave)
                        .alert("已保存", isPresented: $showSaved) {
                            Button("好的") { dismiss() }
                        } message: {
                            Text("活动已更新")
                        }

                        Divider().overlay(EMTheme.line)

                        if event.isActive {
                            HStack {
                                Text("状态：已启用")
                                    .font(.footnote)
                                    .foregroundStyle(.green)
                                Spacer()
                                Text("当前活动")
                                    .font(.footnote)
                                    .foregroundStyle(EMTheme.ink2)
                            }
                        } else {
                            Button("设为启用") {
                                Task { await makeActive() }
                            }
                            .buttonStyle(EMSecondaryButtonStyle())
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task { await load() }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedFormId != nil
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            forms = try await service.listForms()
            if selectedFormId == nil {
                selectedFormId = forms.first?.id
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let formId = selectedFormId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await service.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                startsAt: startsAt,
                endsAt: endsAt < startsAt ? startsAt : endsAt,
                host: host.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                assistant: assistant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                formId: formId
            )
            errorMessage = nil
            showSaved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeActive() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.setActive(eventId: event.id)
            errorMessage = nil
            showSaved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
