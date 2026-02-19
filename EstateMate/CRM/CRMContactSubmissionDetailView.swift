//
//  CRMContactSubmissionDetailView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-18.
//

import SwiftUI
import Supabase

/// Submission detail screen for a CRM contact.
/// Renders the submission using the original form schema (submission.formId ?? event.formId).
struct CRMContactSubmissionDetailView: View {
    let contactId: UUID
    let submission: SubmissionV2

    private let service = DynamicFormService()

    @State private var event: OpenHouseEventV2?
    @State private var form: FormRecord?

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(eventTitle, subtitle: headerSubtitle)

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
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 12) {
                            let pairs = displayPairs()
                            if pairs.isEmpty {
                                Text(form == nil ? "字段加载中..." : "暂无可显示的字段")
                                    .font(.callout)
                                    .foregroundStyle(EMTheme.ink2)
                                    .padding(.vertical, 2)
                            } else {
                                ForEach(pairs, id: \.0) { label, value in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(label)
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(EMTheme.ink2)
                                        Text(value.isEmpty ? "—" : value)
                                            .font(.body)
                                            .foregroundStyle(EMTheme.ink)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    if label != pairs.last?.0 {
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
        .navigationTitle("提交")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private var eventTitle: String {
        if let event {
            return event.title.isEmpty ? "活动策划" : event.title
        }
        return "活动策划"
    }

    private var headerSubtitle: String {
        let whenText = submission.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? ""
        let loc = (event?.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if whenText.isEmpty { return loc }
        if loc.isEmpty { return whenText }
        return "\(whenText) · \(loc)"
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let e = try await service.getEvent(id: submission.eventId)
            event = e

            let formId = submission.formId ?? e.formId
            form = try await service.getForm(id: formId)

            errorMessage = nil
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func displayPairs() -> [(String, String)] {
        guard let form else { return [] }

        var out: [(String, String)] = []
        for field in form.schema.fields {
            switch field.type {
            case .name:
                let keys = field.nameKeys ?? ["full_name"]
                let parts = keys
                    .compactMap { submission.data[$0]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let value = parts.joined(separator: " ")
                if value.isEmpty == false { out.append((field.label, value))
                }

            case .phone:
                if (field.phoneFormat ?? .plain) == .withCountryCode {
                    let keys = field.phoneKeys ?? [field.key]
                    let cc = keys.indices.contains(0) ? (submission.data[keys[0]]?.stringValue ?? "") : ""
                    let num = keys.indices.contains(1) ? (submission.data[keys[1]]?.stringValue ?? "") : ""
                    let value = ([cc, num].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }).joined(separator: " ")
                    if value.isEmpty == false { out.append((field.label, value)) }
                } else {
                    let value = submission.data[field.key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if value.isEmpty == false { out.append((field.label, value)) }
                }

            case .text, .multilineText, .email, .select, .dropdown, .date, .time, .address:
                let value = submission.data[field.key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if value.isEmpty == false { out.append((field.label, value)) }

            case .multiSelect:
                let arr = submission.data[field.key]?.arrayValue ?? []
                let value = arr.compactMap { $0.stringValue }.filter { !$0.isEmpty }.joined(separator: "、")
                if value.isEmpty == false { out.append((field.label, value)) }

            case .checkbox:
                let b = submission.data[field.key]?.boolValue ?? false
                if b {
                    out.append((field.label, "是"))
                }

            case .sectionTitle, .sectionSubtitle, .divider, .splice:
                // Display-only fields: do not appear in submission.data
                break
            }
        }

        return out
    }
}
