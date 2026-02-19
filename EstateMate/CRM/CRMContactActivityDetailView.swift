//
//  CRMContactActivityDetailView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-18.
//

import SwiftUI

struct CRMContactActivityDetailView: View {
    let contactId: UUID
    let event: OpenHouseEventV2
    let submissions: [SubmissionV2]

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(event.title, subtitle: subtitleText)

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
                                metaRow(icon: "mappin.and.ellipse", text: location)
                            }

                            if let time = timeText.nilIfBlank {
                                metaRow(icon: "clock", text: time)
                            }

                            if let host = event.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
                                metaRow(icon: "person", text: "主理人：\(host)")
                            }

                            if let assistant = event.assistant?.trimmingCharacters(in: .whitespacesAndNewlines), !assistant.isEmpty {
                                metaRow(icon: "person.2", text: "助手：\(assistant)")
                            }
                        }
                    }

                    EMSectionHeader("该客户的提交（\(submissions.count)）", subtitle: "只展示这个客户在该活动下填写过的表单")

                    if submissions.isEmpty {
                        EMCard {
                            Text("暂无提交")
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.vertical, 10)
                        }
                    } else {
                        ForEach(submissions.sorted(by: { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) })) { s in
                            NavigationLink {
                                CRMContactSubmissionDetailView(contactId: contactId, submission: s)
                            } label: {
                                EMCard {
                                    HStack {
                                        Text(s.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(EMTheme.ink)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(EMTheme.ink2)
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
        .navigationTitle("活动详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var subtitleText: String {
        if submissions.isEmpty { return "该客户暂无提交" }
        return "该客户提交：\(submissions.count)"
    }

    private var timeText: String {
        guard let start = event.startsAt else { return "" }
        let startText = start.formatted(date: .abbreviated, time: .shortened)
        if let end = event.endsAt {
            let endText = end.formatted(date: .omitted, time: .shortened)
            return "\(startText) – \(endText)"
        } else {
            return startText
        }
    }

    @ViewBuilder
    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(EMTheme.ink2)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(EMTheme.ink2)
                .lineLimit(2)
        }
    }
}

// #Preview {
//     NavigationStack {
//         CRMContactActivityDetailView(contactId: UUID(), event: OpenHouseEventV2(id: UUID(), ownerId: nil, title: "50 Morecambe Gate - 2月14日", location: "Toronto", startsAt: Date(), endsAt: nil, endedAt: nil, host: "嘉树", assistant: "Jason", formId: UUID(), emailTemplateId: nil, isActive: false, createdAt: nil), submissions: [])
//     }
// }
