//
//  OpenHouseEventHubView.swift
//  EstateMate
//

import Foundation
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    tab = .create
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

private struct OpenHouseEventCreateCardView: View {
    private let service = DynamicFormService()

    @State private var locationService = LocationAddressService()

    @State private var forms: [FormRecord] = []
    @State private var events: [OpenHouseEventV2] = []

    @State private var templates: [EmailTemplateRecord] = []
    @State private var selectedEmailTemplateId: UUID?
    @State private var isEmailTemplateSheetPresented: Bool = false

    @State private var newTitle: String = ""
    @State private var location: String = ""
    @State private var startsAt: Date = Date()
    @State private var hasTimeRange: Bool = false
    @State private var endsAt: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var host: String = ""
    @State private var assistant: String = ""

    @State private var selectedFormId: UUID?
    @State private var isFormSheetPresented: Bool = false
    @State private var isFormManagementPresented: Bool = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreated = false

    @State private var isFillingLocation = false
    @State private var locationErrorMessage: String?
    @State private var showLocationError = false

    var body: some View {
        EMCard {
            Text("新建活动")
                .font(.headline)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("活动标题")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)

                HStack(spacing: 10) {
                    TextField("例如：123 Main St - 2月10日", text: $newTitle)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)

                    Button {
                        hideKeyboard()
                        Task { await fillTitleFromCurrentLocation() }
                    } label: {
                        if isFillingLocation {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.callout.weight(.semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(EMTheme.accent)
                    .disabled(isFillingLocation)
                    .accessibilityLabel("使用当前位置生成标题")
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

            EMLocationField(
                title: "活动地点",
                text: $location,
                prompt: "例如：123 Main St, Toronto",
                isLoading: isFillingLocation,
                onFillFromCurrentLocation: {
                    hideKeyboard()
                    Task { await fillLocationFromCurrent() }
                }
            )
            .alert("无法获取当前位置", isPresented: $showLocationError) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(locationErrorMessage ?? "请稍后重试")
            }

            DatePicker("开始时间", selection: $startsAt)
                .datePickerStyle(.compact)
                .onChange(of: startsAt) { _, newValue in
                    // Keep end >= start when time range is enabled.
                    if hasTimeRange, endsAt < newValue {
                        endsAt = newValue
                    }
                }

            Toggle("设置时间段", isOn: $hasTimeRange)
                .onChange(of: hasTimeRange) { _, newValue in
                    guard newValue else { return }
                    // When enabling time range, ensure end is not earlier than start.
                    if endsAt < startsAt {
                        endsAt = startsAt
                    }
                }

            if hasTimeRange {
                DatePicker(
                    "结束时间",
                    selection: $endsAt,
                    in: startsAt...
                )
                .datePickerStyle(.compact)
            }

            // 从历史活动里提取“主理人/助手”候选，方便快速选择
            let hostOptions = Array(Set(events.compactMap { $0.host?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
            let assistantOptions = Array(Set(events.compactMap { $0.assistant?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()

            VStack(alignment: .leading, spacing: 8) {
                Text("主理人")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)

                EMTextField(title: "", text: $host, prompt: "例如：嘉树")

                if !hostOptions.isEmpty {
                    FlowLayout(maxPerRow: 3, spacing: 8) {
                        ForEach(Array(hostOptions.prefix(3)), id: \.self) { option in
                            Button {
                                hideKeyboard()
                                host = option
                            } label: {
                                EMChip(text: option, isOn: host == option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("助手")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)

                EMTextField(title: "", text: $assistant, prompt: "例如：Jason")

                if !assistantOptions.isEmpty {
                    FlowLayout(maxPerRow: 3, spacing: 8) {
                        ForEach(Array(assistantOptions.prefix(3)), id: \.self) { option in
                            Button {
                                hideKeyboard()
                                assistant = option
                            } label: {
                                EMChip(text: option, isOn: assistant == option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("绑定表单")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)

                Button {
                    if forms.isEmpty {
                        isFormManagementPresented = true
                    } else {
                        isFormSheetPresented = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        if selectedFormId == nil {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(EMTheme.accent)
                            Text("绑定表单")
                                .foregroundStyle(EMTheme.ink)
                        } else {
                            Text(selectedFormName)
                                .foregroundStyle(EMTheme.ink)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    Divider().overlay(EMTheme.line)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("绑定邮件模版")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)

                Button {
                    isEmailTemplateSheetPresented = true
                } label: {
                    HStack(spacing: 10) {
                        if selectedEmailTemplateId == nil {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(EMTheme.accent)
                            Text("绑定邮件模版")
                                .foregroundStyle(EMTheme.ink)
                        } else {
                            Text(selectedEmailTemplateName)
                                .foregroundStyle(EMTheme.ink)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    Divider().overlay(EMTheme.line)
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
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task { await load() }
        .sheet(isPresented: $isFormSheetPresented) {
            FormPickerSheetView(forms: forms, selectedFormId: $selectedFormId)
        }
        .sheet(isPresented: $isFormManagementPresented, onDismiss: {
            Task {
                await load()
                if selectedFormId == nil && forms.isEmpty == false {
                    isFormSheetPresented = true
                }
            }
        }) {
            NavigationStack {
                OpenHouseFormsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("取消") { isFormManagementPresented = false }
                                .foregroundStyle(EMTheme.ink2)
                        }
                    }
            }
        }
        .sheet(isPresented: $isEmailTemplateSheetPresented) {
            NavigationStack {
                EmailTemplatesListView(workspace: .openhouse, selection: $selectedEmailTemplateId)
            }
        }
    }

    private var canCreate: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedFormId != nil
    }

    private var selectedFormName: String {
        guard let selectedFormId else { return "请选择..." }
        return forms.first(where: { $0.id == selectedFormId })?.name ?? "请选择..."
    }

    private var selectedEmailTemplateName: String {
        guard let selectedEmailTemplateId else { return "请选择..." }
        let t = templates.first(where: { $0.id == selectedEmailTemplateId })
        let name = (t?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "（未命名模版）" : name
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            forms = try await service.listForms()
            events = try await service.listEvents()
            templates = try await EmailTemplateService().listTemplates(workspace: nil)
            // 不默认选择表单，让用户明确绑定
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fillLocationFromCurrent() async {
        isFillingLocation = true
        defer { isFillingLocation = false }
        do {
            let addr = try await locationService.fillCurrentAddress()
            if !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                location = addr
            }
        } catch {
            locationErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showLocationError = true
        }
    }

    private func fillTitleFromCurrentLocation() async {
        isFillingLocation = true
        defer { isFillingLocation = false }
        do {
            let addr = try await locationService.fillCurrentAddress()
            let trimmed = addr.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            newTitle = suggestedTitle(from: trimmed, date: startsAt)
        } catch {
            locationErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showLocationError = true
        }
    }

    private func suggestedTitle(from address: String, date: Date) -> String {
        let street = address.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? address
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "M月d日"
        let dateText = df.string(from: date)
        let s = street.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? dateText : "\(s) - \(dateText)"
    }

    private func createEvent() async {
        guard let formId = selectedFormId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await service.createEvent(
                title: newTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                startsAt: startsAt,
                endsAt: hasTimeRange ? (endsAt < startsAt ? startsAt : endsAt) : nil,
                host: host.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                assistant: assistant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                formId: formId,
                emailTemplateId: selectedEmailTemplateId,
                isActive: events.isEmpty
            )
            newTitle = ""
            location = ""
            host = ""
            assistant = ""
            selectedEmailTemplateId = nil
            startsAt = Date()
            hasTimeRange = false
            endsAt = Calendar.current.date(byAdding: .hour, value: 2, to: startsAt) ?? startsAt
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
    @State private var forms: [FormRecord] = []

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        EMCard {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if events.isEmpty {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(EMTheme.ink2)

                    Text("还没有任何活动")
                        .font(.headline)
                        .foregroundStyle(EMTheme.ink)

                    Text("先新建一个活动并绑定表单，之后就可以开始现场填写与自动发信。")
                        .font(.footnote)
                        .foregroundStyle(EMTheme.ink2)
                        .multilineTextAlignment(.center)

                    NavigationLink {
                        OpenHouseEventHubView(initialTab: .create)
                    } label: {
                        Text("去新建活动")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if ongoingEvents.isEmpty == false {
                        eventList(ongoingEvents)
                    }

                    if endedEvents.isEmpty == false {
                        if ongoingEvents.isEmpty == false {
                            Divider().overlay(EMTheme.line)
                                .padding(.vertical, 8)
                        }
                        eventList(endedEvents)
                    }

                    if ongoingEvents.isEmpty && endedEvents.isEmpty {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(EMTheme.ink2)
                            Text("暂无活动")
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
        .onAppear {
            Task { await load() }
        }
    }

    private var ongoingEvents: [OpenHouseEventV2] {
        events
            .filter { $0.endedAt == nil }
            .sorted { a, b in
                (a.startsAt ?? .distantFuture) < (b.startsAt ?? .distantFuture)
            }
    }

    private var endedEvents: [OpenHouseEventV2] {
        events
            .filter { $0.endedAt != nil }
            .sorted { a, b in
                (a.endedAt ?? .distantPast) > (b.endedAt ?? .distantPast)
            }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(EMTheme.ink2)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func eventList(_ list: [OpenHouseEventV2]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { idx, e in
                NavigationLink {
                    OpenHouseEventEditView(event: e)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(e.title)
                                .font(.headline)
                                .foregroundStyle(EMTheme.ink)

                            VStack(alignment: .leading, spacing: 6) {
                                if let location = e.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank {
                                    metaRow(icon: "mappin.and.ellipse", text: location)
                                }

                                if let timeText = timeText(for: e).nilIfBlank {
                                    metaRow(icon: "clock", text: timeText)
                                }

                                metaRow(icon: "doc.text", text: "表单：\(formName(for: e))")

                                if let host = e.host?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank {
                                    metaRow(icon: "person", text: "主理人：\(host)")
                                }

                                if let assistant = e.assistant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank {
                                    metaRow(icon: "person.2", text: "助手：\(assistant)")
                                }

                                metaRow(
                                    icon: isEnded(e) ? "xmark.seal.fill" : "checkmark.seal.fill",
                                    text: isEnded(e) ? "已结束" : "进行中",
                                    tint: isEnded(e) ? .red : .green
                                )
                            }
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if idx != list.count - 1 {
                    Divider().overlay(EMTheme.line)
                }
            }
        }
    }

    @ViewBuilder
    private func metaRow(icon: String, text: String, tint: Color? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint ?? EMTheme.ink2)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(tint ?? EMTheme.ink2)
                .lineLimit(2)
        }
    }

    private func formName(for event: OpenHouseEventV2) -> String {
        forms.first(where: { $0.id == event.formId })?.name ?? "（未知表单）"
    }

    private func isEnded(_ event: OpenHouseEventV2) -> Bool {
        event.endedAt != nil
    }

    private func timeText(for event: OpenHouseEventV2) -> String {
        guard let start = event.startsAt else { return "" }
        let startText = start.formatted(date: .abbreviated, time: .shortened)
        if let end = event.endsAt {
            let endText = end.formatted(date: .omitted, time: .shortened)
            return "\(startText) – \(endText)"
        } else {
            return startText
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let eventsTask = service.listEvents()
            async let formsTask = service.listForms()
            events = try await eventsTask
            forms = try await formsTask
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EMLocationField: View {
    let title: String
    @Binding var text: String
    var prompt: String

    var isLoading: Bool
    var onFillFromCurrentLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(EMTheme.ink2)

            HStack(spacing: 10) {
                TextField(prompt, text: $text)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)

                Button {
                    onFillFromCurrentLocation()
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.callout.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(EMTheme.accent)
                .disabled(isLoading)
                .accessibilityLabel("使用当前位置")
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
    }
}
