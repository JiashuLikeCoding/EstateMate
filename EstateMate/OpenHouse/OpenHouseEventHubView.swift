//
//  OpenHouseEventHubView.swift
//  EstateMate
//

import SwiftUI

struct OpenHouseEventHubView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case create = "新建活动"
        case list = "活动列表"
        var id: String { rawValue }
    }

    let initialTab: Tab

    @State private var tab: Tab

    init(initialTab: Tab = .list) {
        self.initialTab = initialTab
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        EMScreen("活动") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case .create:
                        OpenHouseEventCreateCardView()
                    case .list:
                        OpenHouseEventListCardView()
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
    }
}

private struct OpenHouseEventCreateCardView: View {
    private let service = DynamicFormService()

    @State private var forms: [FormRecord] = []
    @State private var events: [OpenHouseEventV2] = []

    @State private var newTitle: String = ""
    @State private var selectedFormId: UUID?

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreated = false

    var body: some View {
        EMCard {
            Text("新建活动")
                .font(.headline)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            EMTextField(title: "活动标题", text: $newTitle, prompt: "例如：123 Main St - 2月10日")

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

            Button(isLoading ? "创建中..." : "创建") {
                Task { await createEvent() }
            }
            .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading || !canCreate))
            .disabled(isLoading || !canCreate)
            .alert("已创建", isPresented: $showCreated) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("活动已创建")
            }

            NavigationLink {
                OpenHouseFormsView()
            } label: {
                Text("去表单管理")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.accent)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task { await load() }
    }

    private var canCreate: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedFormId != nil
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
            showCreated = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct OpenHouseEventListCardView: View {
    private let service = DynamicFormService()

    @State private var events: [OpenHouseEventV2] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        EMCard {
            HStack {
                Text("活动列表")
                    .font(.headline)
                Spacer()
                Button("刷新") { Task { await load() } }
                    .font(.footnote.weight(.medium))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if events.isEmpty {
                Text("暂无活动")
                    .foregroundStyle(EMTheme.ink2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { idx, e in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.title)
                                    .font(.headline)
                                Text(e.isActive ? "已启用" : "未启用")
                                    .font(.caption)
                                    .foregroundStyle(e.isActive ? .green : EMTheme.ink2)
                            }
                            Spacer()
                            if !e.isActive {
                                Button("设为启用") {
                                    Task { await makeActive(e) }
                                }
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.accent)
                            }
                        }
                        .padding(.vertical, 10)

                        if idx != events.count - 1 {
                            Divider().overlay(EMTheme.line)
                        }
                    }
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task { await load() }
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
