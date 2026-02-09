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

    @State private var activeEvent: OpenHouseEventV2?
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
                        EMSectionHeader("准备开始活动", subtitle: "选择活动并设置密码后进入现场填写")

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }

                        if let activeEvent, isOngoing(activeEvent) {
                            EMCard {
                                Text("进行中的活动")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(activeEvent.title)
                                        .font(.title3.weight(.semibold))
                                    if let location = activeEvent.location?.nilIfBlank {
                                        Text(location)
                                            .font(.footnote)
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                }

                                Divider().overlay(EMTheme.line)

                                Button("开始活动") {
                                    Task { await start(event: activeEvent) }
                                }
                                .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                            }
                        } else {
                            EMCard {
                                Text("选择活动")
                                    .font(.headline)

                                if isLoading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                } else if events.isEmpty {
                                    Text("暂无可开始的活动")
                                        .foregroundStyle(EMTheme.ink2)
                                        .padding(.vertical, 10)
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(Array(events.enumerated()), id: \.element.id) { idx, e in
                                            Button {
                                                Task { await start(event: e) }
                                            } label: {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(e.title)
                                                            .font(.headline)
                                                            .foregroundStyle(EMTheme.ink)
                                                        Text(eventSubtitle(e))
                                                            .font(.caption)
                                                            .foregroundStyle(EMTheme.ink2)
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .foregroundStyle(EMTheme.ink2)
                                                }
                                                .padding(.vertical, 10)
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(!canStart(e))
                                            .opacity(canStart(e) ? 1 : 0.45)

                                            if idx != events.count - 1 {
                                                Divider().overlay(EMTheme.line)
                                            }
                                        }
                                    }
                                }
                            }

                            Text("提示：只能开始“未结束且已开始”的活动。")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
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
                selectedEvent = nil
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
                // Defensive: should never happen.
                Text("无法开始活动")
                    .padding()
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            activeEvent = try await service.getActiveEvent()
            let all = try await service.listEvents()
            // Only show events that are not ended; and prefer started ones.
            let now = Date()
            events = all
                .filter { !isEnded($0, now: now) }
                .sorted { (a, b) in
                    // Started first
                    let aStarted = (a.startsAt ?? .distantPast) <= now
                    let bStarted = (b.startsAt ?? .distantPast) <= now
                    if aStarted != bStarted { return aStarted && !bStarted }
                    return (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
                }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func start(event: OpenHouseEventV2) async {
        guard canStart(event) else {
            errorMessage = "该活动尚未开始或已结束，无法开始。"
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            selectedEvent = event
            selectedForm = try await service.getForm(id: event.formId)
            errorMessage = nil

            passwordDraft = ""
            showSetPassword = true
        } catch {
            errorMessage = error.localizedDescription
            selectedEvent = nil
            selectedForm = nil
        }
    }

    private func isEnded(_ e: OpenHouseEventV2, now: Date = Date()) -> Bool {
        if let endsAt = e.endsAt {
            return endsAt < now
        }
        return false
    }

    private func isOngoing(_ e: OpenHouseEventV2, now: Date = Date()) -> Bool {
        if isEnded(e, now: now) { return false }
        if let startsAt = e.startsAt, startsAt > now { return false }
        return true
    }

    private func canStart(_ e: OpenHouseEventV2, now: Date = Date()) -> Bool {
        // Must not be ended, and must not be in the future.
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
