//
//  CRMContactActivityFormDetailView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-18.
//

import SwiftUI
import Supabase

/// From CRM contact -> Activities.
/// Single-level screen: show the activity's form content directly.
/// If the contact has multiple submissions in this activity, allow switching inside this screen.
struct CRMContactActivityFormDetailView: View {
    let contactId: UUID
    let event: OpenHouseEventV2
    let submissions: [SubmissionV2]

    private let service = DynamicFormService()

    @State private var selectedSubmissionId: UUID?

    @State private var form: FormRecord?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var sortedSubmissions: [SubmissionV2] {
        submissions.sorted(by: { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) })
    }

    private var selectedSubmission: SubmissionV2? {
        guard let selectedSubmissionId else {
            return sortedSubmissions.first
        }
        return sortedSubmissions.first(where: { $0.id == selectedSubmissionId }) ?? sortedSubmissions.first
    }

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(event.title, subtitle: headerSubtitle)

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

                    if let submission = selectedSubmission {
                        if sortedSubmissions.count > 1 {
                            EMCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("选择提交")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(EMTheme.ink2)

                                    Picker("", selection: Binding(
                                        get: { selectedSubmissionId ?? submission.id },
                                        set: { newValue in
                                            selectedSubmissionId = newValue
                                            Task { await loadForm(for: newValue) }
                                        }
                                    )) {
                                        ForEach(sortedSubmissions) { s in
                                            Text(s.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                                .tag(s.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }

                        EMCard {
                            VStack(alignment: .leading, spacing: 12) {
                                let pairs = displayPairs(submission: submission)
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
                    } else {
                        EMCard {
                            Text("暂无提交")
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.vertical, 10)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("活动")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            selectedSubmissionId = selectedSubmission?.id
            if let id = selectedSubmission?.id {
                await loadForm(for: id)
            }
        }
        .refreshable {
            if let id = selectedSubmission?.id {
                await loadForm(for: id)
            }
        }
    }

    private var headerSubtitle: String {
        let loc = (event.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let whenText = selectedSubmission?.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? ""

        if whenText.isEmpty { return loc }
        if loc.isEmpty { return whenText }
        return "\(whenText) · \(loc)"
    }

    private func loadForm(for submissionId: UUID) async {
        guard let submission = submissions.first(where: { $0.id == submissionId }) else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let formId = submission.formId ?? event.formId
            form = try await service.getForm(id: formId)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func displayPairs(submission: SubmissionV2) -> [(String, String)] {
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
                if value.isEmpty == false { out.append((field.label, value)) }

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
                if b { out.append((field.label, "是")) }

            case .sectionTitle, .sectionSubtitle, .divider, .splice:
                break
            }
        }

        return out
    }
}
