//
//  OpenHouseEventEditView.swift
//  EstateMate
//

import Foundation
import SwiftUI

struct OpenHouseEventEditView: View {
    @Environment(\.dismiss) private var dismiss

    private let service = DynamicFormService()

    @State private var locationService = LocationAddressService()

    @State private var event: OpenHouseEventV2

    @State private var title: String
    @State private var location: String
    @State private var startsAt: Date
    @State private var hasTimeRange: Bool
    @State private var endsAt: Date
    @State private var host: String
    @State private var assistant: String

    @State private var forms: [FormRecord] = []
    @State private var selectedFormId: UUID?
    @State private var isFormSheetPresented: Bool = false
    @State private var isFormManagementPresented: Bool = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var templates: [EmailTemplateRecord] = []
    @State private var selectedEmailTemplateId: UUID?
    @State private var isEmailTemplateSheetPresented: Bool = false

    @State private var showSaved = false

    @State private var showEndEarlyConfirm = false

    @State private var showDeleteConfirm = false

    @State private var isFillingLocation = false
    @State private var locationErrorMessage: String?
    @State private var showLocationError = false

    init(event: OpenHouseEventV2) {
        _event = State(initialValue: event)
        _title = State(initialValue: event.title)
        _location = State(initialValue: event.location ?? "")
        let start = event.startsAt ?? Date()
        _startsAt = State(initialValue: start)
        _hasTimeRange = State(initialValue: event.endsAt != nil)
        _endsAt = State(initialValue: event.endsAt ?? Calendar.current.date(byAdding: .hour, value: 2, to: start) ?? start)
        _host = State(initialValue: event.host ?? "")
        _assistant = State(initialValue: event.assistant ?? "")
        _selectedFormId = State(initialValue: event.formId)
        _selectedEmailTemplateId = State(initialValue: event.emailTemplateId)
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("活动标题")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            HStack(spacing: 10) {
                                TextField("例如：123 Main St - 2月10日", text: $title)
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

                        Toggle("设置时间段", isOn: $hasTimeRange)

                        if hasTimeRange {
                            DatePicker("结束时间", selection: $endsAt)
                                .datePickerStyle(.compact)

                            if canEndEarly {
                                Button("提前结束活动") {
                                    showEndEarlyConfirm = true
                                }
                                .buttonStyle(EMDangerButtonStyle())
                                .alert("确认提前结束？", isPresented: $showEndEarlyConfirm) {
                                    Button("取消", role: .cancel) {}
                                    Button("结束活动", role: .destructive) {
                                        Task { await endEarly() }
                                    }
                                } message: {
                                    Text("将结束时间设置为当前时间，并把活动移动到“已结束”。")
                                }
                            }
                        }

                        EMTextField(title: "主理人", text: $host, prompt: "例如：嘉树")
                        EMTextField(title: "助手", text: $assistant, prompt: "例如：Jason")

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

                            Text("说明：用于本活动的默认邮件模版（后续可在客户/提交中一键套用）。")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.top, -2)
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

                        VStack(alignment: .leading, spacing: 10) {
                            Text("活动状态")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            HStack(spacing: 10) {
                                if event.endedAt != nil {
                                    Text("已结束")
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                } else {
                                    Text("进行中")
                                        .font(.footnote)
                                        .foregroundStyle(.green)
                                }

                                Spacer()

                                if event.isActive == false {
                                    Button("设为当前活动") {
                                        Task { await makeActive() }
                                    }
                                    .buttonStyle(EMSecondaryButtonStyle())
                                }
                            }

                            if shouldShowMarkOngoing {
                                Button("设为进行中") {
                                    Task { await markOngoing() }
                                }
                                .buttonStyle(EMSecondaryButtonStyle())
                            } else {
                                Button("设为已结束") {
                                    Task { await markEndedNow() }
                                }
                                .buttonStyle(EMDangerButtonStyle())
                            }

                            Button("删除活动") {
                                showDeleteConfirm = true
                            }
                            .buttonStyle(EMDangerButtonStyle())
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
            }
        }
        .sheet(isPresented: $isEmailTemplateSheetPresented) {
            EmailTemplatePickerSheetView(templates: templates, selectedTemplateId: $selectedEmailTemplateId)
        }
        .alert("删除这个活动？", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task { await deleteEvent() }
            }
        } message: {
            Text("删除后无法恢复，并会同时删除该活动下的所有提交记录")
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedFormId != nil
    }

    private var canEndEarly: Bool {
        // Only show when event has a time range and is not yet ended.
        hasTimeRange && endsAt > Date()
    }

    private var shouldShowMarkOngoing: Bool {
        // Only show ONE of: "设为进行中" vs "设为已结束"
        // Status is MANUAL only:
        // - ended_at != nil -> ended -> show "设为进行中"
        // - ended_at == nil -> ongoing -> show "设为已结束"
        event.endedAt != nil
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
            templates = try await EmailTemplateService().listTemplates(workspace: nil)
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
            title = suggestedTitle(from: trimmed, date: startsAt)
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

    private func save() async {
        guard let formId = selectedFormId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await service.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                startsAt: startsAt,
                endsAt: hasTimeRange ? (endsAt < startsAt ? startsAt : endsAt) : nil,
                host: host.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                assistant: assistant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                formId: formId,
                emailTemplateId: selectedEmailTemplateId
            )
            // Keep manual state (isActive / endedAt) in sync too.
            event = updated
            errorMessage = nil
            showSaved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func endEarly() async {
        guard let formId = selectedFormId else { return }
        let now = Date()
        let end = max(startsAt, now)

        isLoading = true
        defer { isLoading = false }
        do {
            // 1) Update scheduled end time (planning info)
            _ = try await service.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                startsAt: startsAt,
                endsAt: end,
                host: host.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                assistant: assistant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                formId: formId,
                emailTemplateId: selectedEmailTemplateId
            )

            // 2) Mark manually ended
            let updated = try await service.markEventEnded(eventId: event.id, endedAt: now)
            event = updated

            endsAt = end
            hasTimeRange = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeActive() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.setActive(eventId: event.id)
            event.isActive = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markOngoing() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await service.markEventOngoing(eventId: event.id)
            event = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markEndedNow() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await service.markEventEnded(eventId: event.id, endedAt: Date())
            event = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteEvent() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.deleteEvent(id: event.id)
            errorMessage = nil
            dismiss()
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
