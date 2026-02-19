//
//  CRMContactsEventPickerView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMContactsEventPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let currentEventId: UUID?
    let onPick: (_ event: OpenHouseEventV2?) -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var events: [OpenHouseEventV2] = []

    private let service = DynamicFormService()

    var body: some View {
        NavigationStack {
            EMScreen {
                List {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }

                    Button {
                        onPick(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Text("（不限制活动）")
                            Spacer()
                            if currentEventId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(EMTheme.accent)
                            }
                        }
                    }

                    Section("活动策划") {
                        ForEach(events, id: \.id) { ev in
                            Button {
                                onPick(ev)
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ev.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(EMTheme.ink)

                                        Text(openHouseEventMetaLine(ev))
                                            .font(.caption)
                                            .foregroundStyle(EMTheme.ink2)
                                            .lineLimit(2)

                                        Text(openHouseEventPeopleLine(ev))
                                            .font(.caption2)
                                            .foregroundStyle(EMTheme.ink2)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    if currentEventId == ev.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(EMTheme.accent)
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(EMTheme.paper)
            }
            .navigationTitle("选择活动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            events = try await service.listEvents()
        } catch {
            errorMessage = "加载活动失败：\(error.localizedDescription)"
        }
    }
}

private func openHouseEventMetaLine(_ ev: OpenHouseEventV2) -> String {
    var bits: [String] = []
    if let startsAt = ev.startsAt {
        bits.append(CRMDate.shortDateTime.string(from: startsAt))
    }
    if let endsAt = ev.endsAt {
        bits.append("~ \(CRMDate.shortDateTime.string(from: endsAt))")
    }
    if let location = ev.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
        bits.append(location)
    }
    return bits.joined(separator: " · ")
}

private func openHouseEventPeopleLine(_ ev: OpenHouseEventV2) -> String {
    let host = ev.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let assistant = ev.assistant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    var bits: [String] = []
    if !host.isEmpty { bits.append("主理：\(host)") }
    if !assistant.isEmpty { bits.append("助手：\(assistant)") }
    return bits.joined(separator: " · ")
}
