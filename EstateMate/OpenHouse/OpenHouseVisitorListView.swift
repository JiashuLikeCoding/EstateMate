//
//  OpenHouseVisitorListView.swift
//  EstateMate
//

import SwiftUI

/// 访客列表（已提交）入口：活动从新到旧，点活动进入该活动的访客提交列表。
struct OpenHouseVisitorListView: View {
    private let service = DynamicFormService()

    @State private var events: [OpenHouseEventV2] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        EMScreen("访客列表") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("选择活动", subtitle: "按从新到旧排序，点击查看该活动所有访客")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    if isLoading {
                        EMCard {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    } else if events.isEmpty {
                        EMCard {
                            Text("暂无活动")
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.vertical, 10)
                        }
                    } else {
                        EMCard {
                            VStack(spacing: 0) {
                                ForEach(Array(events.enumerated()), id: \.element.id) { idx, e in
                                    NavigationLink {
                                        OpenHouseSubmissionsListView(event: e)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(e.title)
                                                .font(.headline)
                                                .foregroundStyle(EMTheme.ink)

                                            if let sub = subtitle(for: e).nilIfBlank {
                                                Text(sub)
                                                    .font(.caption)
                                                    .foregroundStyle(EMTheme.ink2)
                                                    .lineLimit(2)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if idx != events.count - 1 {
                                        Divider().overlay(EMTheme.line)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // service.listEvents() 默认按 created_at 降序（从新到旧）
            events = try await service.listEvents()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func subtitle(for e: OpenHouseEventV2) -> String {
        var parts: [String] = []

        if let startsAt = e.startsAt {
            parts.append(startsAt.formatted(date: .abbreviated, time: .shortened))
        }
        if let endsAt = e.endsAt {
            parts.append("–")
            parts.append(endsAt.formatted(date: .omitted, time: .shortened))
        }
        if let location = e.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank {
            if !parts.isEmpty { parts.append("·") }
            parts.append(location)
        }

        return parts.joined(separator: " ")
    }
}

#Preview {
    NavigationStack {
        OpenHouseVisitorListView()
    }
}
