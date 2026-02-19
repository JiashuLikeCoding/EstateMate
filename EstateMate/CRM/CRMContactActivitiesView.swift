//
//  CRMContactActivitiesView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMContactActivitiesView: View {
    let contactId: UUID

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var rows: [(event: OpenHouseEventV2, submissions: [SubmissionV2])] = []

    private let formService = DynamicFormService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("参与的活动", subtitle: "按开放日活动聚合展示")

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    if isLoading {
                        EMCard {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("正在加载…")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    if !isLoading, rows.isEmpty, errorMessage == nil {
                        EMCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("暂无记录")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)
                                Text("这个客户还没有关联到任何开放日提交")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                            }
                        }
                    }

                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        NavigationLink {
                            CRMContactActivityDetailView(contactId: contactId, event: row.event, submissions: row.submissions)
                        } label: {
                            EMCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(row.event.title)
                                        .font(.headline)
                                        .foregroundStyle(EMTheme.ink)

                                    HStack(spacing: 10) {
                                        Text("提交：\(row.submissions.count)")
                                            .font(.footnote)
                                            .foregroundStyle(EMTheme.ink2)

                                        if let location = row.event.location, !location.isEmpty {
                                            Text(location)
                                                .font(.footnote)
                                                .foregroundStyle(EMTheme.ink2)
                                                .lineLimit(1)
                                        }

                                        Spacer()
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("参与的活动")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let subs = try await formService.listSubmissions(contactId: contactId)
            if subs.isEmpty {
                rows = []
                return
            }

            let events = try await formService.listEvents()
            let byEvent = Dictionary(grouping: subs, by: { $0.eventId })

            let mapped: [(OpenHouseEventV2, [SubmissionV2])] = events.compactMap { e in
                guard let s = byEvent[e.id] else { return nil }
                return (e, s)
            }

            // keep the event order from listEvents (created_at desc)
            rows = mapped.map { (event: $0.0, submissions: $0.1) }
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        CRMContactActivitiesView(contactId: UUID())
    }
}
