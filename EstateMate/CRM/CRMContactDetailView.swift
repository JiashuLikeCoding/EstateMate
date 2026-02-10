//
//  CRMContactDetailView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMContactDetailView: View {
    let contactId: UUID

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var contact: CRMContact?
    @State private var customFields: [CRMContactCustomField] = []

    struct ContactNavTarget: Identifiable, Equatable, Hashable {
        let id: UUID
    }

    @State private var isEditPresented = false
    @State private var mergedIntoContact: ContactNavTarget? = nil

    private let service = CRMService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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

                    if let contact {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(contact.fullName.isEmpty ? "（未命名）" : contact.fullName)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(EMTheme.ink)

                            Spacer(minLength: 0)

                            // 阶段只展示当前值（编辑请进右上角“编辑”）。
                            EMChip(text: contact.stage.displayName, isOn: true)
                        }

                        EMCard {
                            infoRow(label: "手机号", value: contact.phone)

                            Divider().overlay(EMTheme.line)
                            infoRow(label: "邮箱", value: contact.email)

                            Divider().overlay(EMTheme.line)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("感兴趣的地址")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)

                                let addresses = splitInterestedAddresses(contact.address)
                                if addresses.isEmpty {
                                    Text("—")
                                        .font(.body)
                                        .foregroundStyle(EMTheme.ink)
                                } else {
                                    FlowLayout(maxPerRow: 3, spacing: 8) {
                                        ForEach(addresses, id: \.self) { a in
                                            EMChip(text: a, isOn: true)
                                        }
                                    }
                                }
                            }

                            Divider().overlay(EMTheme.line)
                            infoRow(label: "备注", value: contact.notes)

                            Divider().overlay(EMTheme.line)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("标签")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)

                                let tags = contact.tags ?? []
                                if tags.isEmpty {
                                    Text("—")
                                        .font(.body)
                                        .foregroundStyle(EMTheme.ink)
                                } else {
                                    FlowLayout(maxPerRow: 99, spacing: 8) {
                                        ForEach(tags, id: \.self) { t in
                                            EMChip(text: t, isOn: true)
                                        }
                                    }
                                }
                            }
                        }

                        if !customFields.isEmpty {
                            EMCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("表单信息")
                                        .font(.headline)
                                        .foregroundStyle(EMTheme.ink)

                                    let sections = groupedCustomFieldSections()
                                    ForEach(Array(sections.enumerated()), id: \.element.id) { idx, section in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(section.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(EMTheme.ink)

                                            if !section.subtitle.isEmpty {
                                                Text(section.subtitle)
                                                    .font(.footnote)
                                                    .foregroundStyle(EMTheme.ink2)
                                            }

                                            ForEach(section.items, id: \.id) { item in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(item.fieldLabel.isEmpty ? item.fieldKey : item.fieldLabel)
                                                        .font(.footnote.weight(.medium))
                                                        .foregroundStyle(EMTheme.ink2)
                                                    Text(item.valueText.isEmpty ? "—" : item.valueText)
                                                        .font(.body)
                                                        .foregroundStyle(EMTheme.ink)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            }

                                            if idx != sections.count - 1 {
                                                Divider().overlay(EMTheme.line)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        EMCard {
                            VStack(alignment: .leading, spacing: 0) {
                                NavigationLink {
                                    CRMContactActivitiesView(contactId: contactId)
                                } label: {
                                    linkRow(icon: "calendar", title: "参与的活动")
                                }
                                .buttonStyle(.plain)

                                Divider().overlay(EMTheme.line)

                                NavigationLink {
                                    CRMEmailLogsView(contactId: contactId)
                                } label: {
                                    linkRow(icon: "envelope", title: "来往的邮件")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("客户")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $mergedIntoContact) { target in
            CRMContactDetailView(contactId: target.id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") {
                    isEditPresented = true
                }
                .disabled(contact == nil)
            }
        }
        .sheet(isPresented: $isEditPresented, onDismiss: {
            Task { await reload() }
        }) {
            NavigationStack {
                CRMContactEditView(mode: .edit(contactId)) { mergedId in
                    // A different contact already exists with this unique key (email/phone).
                    // We merged updates into that contact; navigate to it.
                    mergedIntoContact = ContactNavTarget(id: mergedId)
                }
            }
        }
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
            contact = try await service.getContact(id: contactId)
            customFields = (try? await service.listCustomFields(contactId: contactId)) ?? []
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(EMTheme.ink2)
            Text(value.isEmpty ? "—" : value)
                .font(.body)
                .foregroundStyle(EMTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 阶段在详情页只展示当前值（见标题右侧 chip），修改请进“编辑”。

    private func linkRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(EMTheme.accent)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(EMTheme.accent.opacity(0.10))
                )

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(EMTheme.ink)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(EMTheme.ink2.opacity(0.7))
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private struct CustomFieldSection: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let items: [CRMContactCustomField]
    }

    private func groupedCustomFieldSections() -> [CustomFieldSection] {
        // Group by submission (best key), else fall back to created_at day.
        let grouped = Dictionary(grouping: customFields) { f in
            (f.submissionId?.uuidString) ?? "day:\(Calendar.current.startOfDay(for: f.createdAt).timeIntervalSince1970)"
        }

        func formatDateTime(_ d: Date?) -> String {
            guard let d else { return "" }
            let df = DateFormatter()
            df.locale = .current
            df.timeZone = .current
            df.dateFormat = "yyyy-MM-dd HH:mm"
            return df.string(from: d)
        }

        let sections: [CustomFieldSection] = grouped.values.map { items in
            let first = items.first!
            let title = first.eventTitle.isEmpty ? "开放日" : first.eventTitle

            var subtitleParts: [String] = []
            let whenText = formatDateTime(first.submittedAt)
            if !whenText.isEmpty { subtitleParts.append(whenText) }
            if !first.eventLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                subtitleParts.append(first.eventLocation)
            }

            let sorted = items.sorted { a, b in
                (a.createdAt, a.fieldKey) > (b.createdAt, b.fieldKey)
            }

            return CustomFieldSection(
                id: first.submissionId?.uuidString ?? "day:\(Calendar.current.startOfDay(for: first.createdAt).timeIntervalSince1970)",
                title: title,
                subtitle: subtitleParts.joined(separator: " · "),
                items: sorted
            )
        }

        // Sort sections by submitted_at/created_at desc.
        return sections.sorted { a, b in
            let aDate = a.items.first?.submittedAt ?? a.items.first?.createdAt ?? .distantPast
            let bDate = b.items.first?.submittedAt ?? b.items.first?.createdAt ?? .distantPast
            return aDate > bDate
        }
    }

    private func splitInterestedAddresses(_ raw: String) -> [String] {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return [] }

        // 不用逗号拆分（地址里常见逗号）。
        let normalized = s
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: ";", with: "\n")
            .replacingOccurrences(of: "；", with: "\n")
            .replacingOccurrences(of: "|", with: "\n")
            .replacingOccurrences(of: "、", with: "\n")

        return normalized
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
