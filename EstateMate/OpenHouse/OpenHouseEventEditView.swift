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

    let event: OpenHouseEventV2

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

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showSaved = false

    @State private var showEndEarlyConfirm = false

    @State private var showDeleteConfirm = false

    @State private var isFillingLocation = false
    @State private var locationErrorMessage: String?
    @State private var showLocationError = false

    init(event: OpenHouseEventV2) {
        self.event = event
        _title = State(initialValue: event.title)
        _location = State(initialValue: event.location ?? "")
        let start = event.startsAt ?? Date()
        _startsAt = State(initialValue: start)
        _hasTimeRange = State(initialValue: event.endsAt != nil)
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
                                isFormSheetPresented = true
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
                            .disabled(forms.isEmpty)
                            .opacity(forms.isEmpty ? 0.4 : 1)
                            .overlay(alignment: .bottom) {
                                Divider().overlay(EMTheme.line)
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

                        VStack(alignment: .leading, spacing: 10) {
                            Text("活动状态")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            HStack(spacing: 10) {
                                if event.isActive {
                                    Text("已启用")
                                        .font(.footnote)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("未启用")
                                        .font(.footnote)
                                        .foregroundStyle(EMTheme.ink2)
                                }

                                Spacer()

                                if event.isActive == false {
                                    Button("设为进行中") {
                                        Task { await makeActive() }
                                    }
                                    .buttonStyle(EMSecondaryButtonStyle())
                                }
                            }

                            HStack(spacing: 10) {
                                Button("设为进行中") {
                                    Task { await markOngoing() }
                                }
                                .buttonStyle(EMSecondaryButtonStyle())

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

    private var selectedFormName: String {
        guard let selectedFormId else { return "请选择..." }
        return forms.first(where: { $0.id == selectedFormId })?.name ?? "请选择..."
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            forms = try await service.listForms()
            // 不默认选择表单，让用户明确绑定/修改
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
                endsAt: hasTimeRange ? (endsAt < startsAt ? startsAt : endsAt) : nil,
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

    private func endEarly() async {
        guard let formId = selectedFormId else { return }
        let now = Date()
        let end = max(startsAt, now)

        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await service.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                startsAt: startsAt,
                endsAt: end,
                host: host.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                assistant: assistant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                formId: formId
            )
            endsAt = end
            hasTimeRange = true
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

    private func markOngoing() async {
        guard let formId = selectedFormId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await service.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                startsAt: startsAt,
                endsAt: nil,
                host: host.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                assistant: assistant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                formId: formId
            )
            hasTimeRange = false
            errorMessage = nil
            showSaved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markEndedNow() async {
        guard let formId = selectedFormId else { return }
        let now = Date()
        let end = max(startsAt, now)

        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await service.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                startsAt: startsAt,
                endsAt: end,
                host: host.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                assistant: assistant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                formId: formId
            )
            endsAt = end
            hasTimeRange = true
            errorMessage = nil
            showSaved = true
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
