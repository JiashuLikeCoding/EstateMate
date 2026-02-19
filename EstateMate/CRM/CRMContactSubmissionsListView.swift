//
//  CRMContactSubmissionsListView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-18.
//

import SwiftUI

/// Drill-down list for a CRM contact: shows each OpenHouse submission (one row per submission).
struct CRMContactSubmissionsListView: View {
    let contactId: UUID

    private let service = DynamicFormService()

    @State private var submissions: [SubmissionV2] = []
    @State private var eventsById: [UUID: OpenHouseEventV2] = [:]

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("填写过的表单", subtitle: "按时间倒序")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
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
                    } else if submissions.isEmpty {
                        EMCard {
                            Text("暂无提交")
                                .font(.callout)
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.vertical, 10)
                        }
                    } else {
                        ForEach(submissions) { s in
                            NavigationLink {
                                CRMContactSubmissionDetailView(contactId: contactId, submission: s)
                            } label: {
                                EMCard {
                                    HStack(alignment: .center, spacing: 12) {
                                        Image(systemName: "doc.text")
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(EMTheme.accent)
                                            .frame(width: 28, height: 28)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(EMTheme.accent.opacity(0.10))
                                            )

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(eventTitle(for: s))
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(EMTheme.ink)
                                                .lineLimit(2)

                                            Text(s.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                                .font(.footnote)
                                                .foregroundStyle(EMTheme.ink2)
                                        }

                                        Spacer(minLength: 0)

                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(EMTheme.ink2.opacity(0.7))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("表单")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func eventTitle(for submission: SubmissionV2) -> String {
        if let e = eventsById[submission.eventId] {
            return e.title.isEmpty ? "活动策划" : e.title
        }
        return "活动策划"
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let subs = try await service.listSubmissions(contactId: contactId)
            submissions = subs

            let eventIds = Set(subs.map { $0.eventId })
            if eventIds.isEmpty {
                eventsById = [:]
                errorMessage = nil
                return
            }

            var map: [UUID: OpenHouseEventV2] = [:]
            try await withThrowingTaskGroup(of: (UUID, OpenHouseEventV2).self) { group in
                for id in eventIds {
                    group.addTask {
                        let e = try await service.getEvent(id: id)
                        return (id, e)
                    }
                }
                for try await (id, e) in group {
                    map[id] = e
                }
            }

            eventsById = map
            errorMessage = nil
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
}
