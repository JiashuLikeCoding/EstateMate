//
//  OpenHouseStartActivityView.swift
//  EstateMate
//
//  Start Activity (Kiosk) flow:
//  - If there is an ongoing active event -> require password -> show kiosk form
//  - Else show event list -> pick event -> require password -> show kiosk form
//

import SwiftUI

struct OpenHouseStartActivityView: View {
    private let service = DynamicFormService()

    @State private var events: [OpenHouseEventV2] = []

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var selectedEvent: OpenHouseEventV2?
    @State private var selectedForm: FormRecord?

    @State private var password: String = ""

    @State private var showSetPassword = false
    @State private var passwordDraft = ""

    @State private var showKiosk = false

    var body: some View {
        EMScreen("准备开始活动") {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        EMSectionHeader("选择活动", subtitle: "先选择活动，再点击“开始活动”进入现场填写")

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }

                        EMCard {
                            Text("活动列表")
                                .font(.headline)

                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            } else if events.isEmpty {
                                Text("暂无活动")
                                    .foregroundStyle(EMTheme.ink2)
                                    .padding(.vertical, 10)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(events.enumerated()), id: \.element.id) { idx, e in
                                        Button {
                                            selectedEvent = e
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: selectedEvent?.id == e.id ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedEvent?.id == e.id ? EMTheme.accent : EMTheme.ink2)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(e.title)
                                                        .font(.headline)
                                                        .foregroundStyle(EMTheme.ink)
                                                    Text(eventSubtitle(e))
                                                        .font(.caption)
                                                        .foregroundStyle(EMTheme.ink2)
                                                }

                                                Spacer()
                                            }
                                            .padding(.vertical, 10)
                                        }
                                        .buttonStyle(.plain)

                                        if idx != events.count - 1 {
                                            Divider().overlay(EMTheme.line)
                                        }
                                    }
                                }
                            }
                        }

                        EMCard {
                            Text("开始")
                                .font(.headline)

                            if let selectedEvent {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(selectedEvent.title)
                                        .font(.title3.weight(.semibold))
                                    if let location = selectedEvent.location?.nilIfBlank {
                                        Text(location)
                                            .font(.footnote)
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                }

                                Divider().overlay(EMTheme.line)

                                Button("开始活动") {
                                    Task { await startSelectedEvent() }
                                }
                                .buttonStyle(EMPrimaryButtonStyle(disabled: !canStart(selectedEvent)))
                                .disabled(!canStart(selectedEvent))

                                if !canStart(selectedEvent) {
                                    Text("该活动尚未开始或已结束，暂时不能开始。")
                                        .font(.footnote)
                                        .foregroundStyle(EMTheme.ink2)
                                }
                            } else {
                                Text("请先在上方选择一个活动")
                                    .foregroundStyle(EMTheme.ink2)
                                    .padding(.vertical, 6)

                                Button("开始活动") {}
                                    .buttonStyle(EMPrimaryButtonStyle(disabled: true))
                                    .disabled(true)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(EMTheme.padding)
                }

                if isLoading {
                    ProgressView()
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .alert("设置密码", isPresented: $showSetPassword) {
            SecureField("密码", text: $passwordDraft)
            Button("开始") {
                password = passwordDraft
                passwordDraft = ""
                showKiosk = true
            }
            Button("取消", role: .cancel) {
                passwordDraft = ""
                selectedForm = nil
            }
        } message: {
            Text("开始活动前需要输入一个密码。返回或查看已提交列表时也需要此密码。")
        }
        .fullScreenCover(isPresented: $showKiosk) {
            if let event = selectedEvent, let form = selectedForm {
                NavigationStack {
                    OpenHouseKioskFillView(event: event, form: form, password: password)
                }
            } else {
                Text("无法开始活动")
                    .padding()
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await service.listEvents()
            let now = Date()
            events = all
                .filter { !isEnded($0, now: now) }
                .sorted { (a, b) in
                    // started first, then newest
                    let aStarted = (a.startsAt ?? .distantPast) <= now
                    let bStarted = (b.startsAt ?? .distantPast) <= now
                    if aStarted != bStarted { return aStarted && !bStarted }
                    return (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
                }

            // keep selection if still exists
            if let selectedId = selectedEvent?.id {
                selectedEvent = events.first(where: { $0.id == selectedId })
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startSelectedEvent() async {
        guard let event = selectedEvent else {
            errorMessage = "请先选择活动。"
            return
        }
        guard canStart(event) else {
            errorMessage = "该活动尚未开始或已结束，无法开始。"
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            selectedForm = try await service.getForm(id: event.formId)
            errorMessage = nil
            passwordDraft = ""
            showSetPassword = true
        } catch {
            errorMessage = error.localizedDescription
            selectedForm = nil
        }
    }

    private func isEnded(_ e: OpenHouseEventV2, now: Date = Date()) -> Bool {
        if let endsAt = e.endsAt {
            return endsAt < now
        }
        return false
    }

    private func canStart(_ e: OpenHouseEventV2, now: Date = Date()) -> Bool {
        if isEnded(e, now: now) { return false }
        if let startsAt = e.startsAt, startsAt > now { return false }
        return true
    }

    private func eventSubtitle(_ e: OpenHouseEventV2) -> String {
        var parts: [String] = []
        if let starts = e.startsAt {
            parts.append(starts.formatted(date: .abbreviated, time: .shortened))
        }
        if let ends = e.endsAt {
            parts.append("~")
            parts.append(ends.formatted(date: .omitted, time: .shortened))
        }
        if let location = e.location?.nilIfBlank {
            parts.append("·")
            parts.append(location)
        }
        return parts.isEmpty ? "" : parts.joined(separator: " ")
    }
}
