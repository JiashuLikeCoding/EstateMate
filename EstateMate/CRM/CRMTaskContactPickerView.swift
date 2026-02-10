//
//  CRMTaskContactPickerView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI
import Supabase
import PostgREST

struct CRMTaskContactPickerView: View {
    enum PickerResult: Equatable {
        case none
        case contact(UUID)
    }

    @Environment(\.dismiss) private var dismiss

    @State private var allContacts: [CRMContact] = []
    @State private var isLoadingContacts = false
    @State private var errorMessage: String?

    let selectedContactId: UUID?
    let onPick: (PickerResult) -> Void

    private let crm = CRMService()

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Section {
                NavigationLink {
                    CRMTaskPickByEventView(selectedContactId: selectedContactId) { result in
                        onPick(result)
                        dismiss()
                    }
                } label: {
                    Text("从活动选择")
                }

                NavigationLink {
                    CRMTaskPickFromAllContactsView(
                        contacts: allContacts,
                        isLoading: isLoadingContacts,
                        selectedContactId: selectedContactId
                    ) { result in
                        onPick(result)
                        dismiss()
                    }
                } label: {
                    Text("从客户列表选择")
                }

                Button {
                    onPick(.none)
                    dismiss()
                } label: {
                    Text("不指定")
                        .foregroundStyle(EMTheme.ink2)
                }
            } header: {
                Text("来源")
            }
        }
        .scrollContentBackground(.hidden)
        .background(EMTheme.paper)
        .navigationTitle("选择客户")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
                    .foregroundStyle(EMTheme.ink2)
            }
        }
        .task {
            await loadAllContacts()
        }
    }

    private func loadAllContacts() async {
        if isLoadingContacts { return }
        if !allContacts.isEmpty { return }

        isLoadingContacts = true
        errorMessage = nil
        defer { isLoadingContacts = false }

        do {
            allContacts = try await crm.listContacts()
        } catch {
            errorMessage = "加载客户失败：\(error.localizedDescription)"
        }
    }
}

private struct CRMTaskPickByEventView: View {
    let selectedContactId: UUID?
    let onPick: (CRMTaskContactPickerView.PickerResult) -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var events: [OpenHouseEventV2] = []
    @State private var searchText: String = ""

    private let openHouse = DynamicFormService()

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if !isLoading, events.isEmpty {
                Text("暂无活动")
                    .foregroundStyle(EMTheme.ink2)
            }

            ForEach(filteredEvents) { e in
                NavigationLink {
                    CRMTaskPickContactFromEventSubmissionsView(
                        event: e,
                        selectedContactId: selectedContactId,
                        onPick: onPick
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(e.title)
                            .foregroundStyle(EMTheme.ink)

                        if let subtitle = eventSubtitle(e), !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(EMTheme.ink2)
                                .lineLimit(2)
                        } else {
                            Text("进入该活动的客户列表")
                                .font(.caption)
                                .foregroundStyle(EMTheme.ink2)
                        }

                        if let hostLine = eventHostLine(e), !hostLine.isEmpty {
                            Text(hostLine)
                                .font(.caption2)
                                .foregroundStyle(EMTheme.ink2)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(EMTheme.paper)
        .navigationTitle("活动")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索活动标题/地点")
        .task {
            await load()
        }
        .refreshable {
            await load(force: true)
        }
    }

    private var filteredEvents: [OpenHouseEventV2] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return events }
        return events.filter { e in
            let hay = [e.title, e.location ?? "", e.host ?? "", e.assistant ?? ""].joined(separator: " ")
            return hay.localizedCaseInsensitiveContains(q)
        }
    }

    private func load(force: Bool = false) async {
        if isLoading { return }
        if !events.isEmpty, !force { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            events = try await openHouse.listEvents()
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func eventSubtitle(_ e: OpenHouseEventV2) -> String? {
        var parts: [String] = []
        if let starts = e.startsAt {
            parts.append(starts.formatted(date: .abbreviated, time: .shortened))
        }
        if let ends = e.endsAt {
            parts.append("~")
            parts.append(ends.formatted(date: .omitted, time: .shortened))
        }
        if let location = e.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
            if !parts.isEmpty { parts.append("·") }
            parts.append(location)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func eventHostLine(_ e: OpenHouseEventV2) -> String? {
        var parts: [String] = []
        if let host = e.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
            parts.append("主理人：\(host)")
        }
        if let assistant = e.assistant?.trimmingCharacters(in: .whitespacesAndNewlines), !assistant.isEmpty {
            parts.append("助手：\(assistant)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  ")
    }
}

private struct CRMTaskPickContactFromEventSubmissionsView: View {
    let event: OpenHouseEventV2
    let selectedContactId: UUID?
    let onPick: (CRMTaskContactPickerView.PickerResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var contacts: [CRMContact] = []
    @State private var searchText: String = ""

    private let crm = CRMService()

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if !isLoading, contacts.isEmpty {
                Text("该活动还没有产生客户（可能还没有提交，或提交未回写 contact_id）。")
                    .foregroundStyle(EMTheme.ink2)
            }

            ForEach(filteredContacts) { c in
                Button {
                    onPick(.contact(c.id))
                    dismiss()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(crmContactTitle(c))
                                .foregroundStyle(EMTheme.ink)

                            if let subtitle = crmContactSubtitle(c), !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)
                                    .lineLimit(2)
                            }

                            if let meta = crmContactMetaLine(c), !meta.isEmpty {
                                Text(meta)
                                    .font(.caption2)
                                    .foregroundStyle(EMTheme.ink2)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if selectedContactId == c.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(EMTheme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
        .background(EMTheme.paper)
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索客户姓名/邮箱/电话/标签")
        .task {
            await load()
        }
        .refreshable {
            await load(force: true)
        }
    }

    private var filteredContacts: [CRMContact] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return contacts }
        return contacts.filter { c in
            let hay = [c.fullName, c.email, c.phone, c.notes, (c.tags ?? []).joined(separator: " ")].joined(separator: " ")
            return hay.localizedCaseInsensitiveContains(q)
        }
    }

    private func load(force: Bool = false) async {
        if isLoading { return }
        if !contacts.isEmpty, !force { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let contactIds = try await listContactIdsForEvent(eventId: event.id)

            var fetched: [CRMContact] = []
            fetched.reserveCapacity(contactIds.count)

            try await withThrowingTaskGroup(of: CRMContact.self) { group in
                for id in contactIds {
                    group.addTask {
                        try await crm.getContact(id: id)
                    }
                }
                for try await c in group {
                    fetched.append(c)
                }
            }

            contacts = fetched.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func listContactIdsForEvent(eventId: UUID) async throws -> [UUID] {
        struct Row: Decodable {
            var contactId: UUID?
            enum CodingKeys: String, CodingKey { case contactId = "contact_id" }
        }

        let rows: [Row] = try await SupabaseClientProvider.client
            .from("openhouse_submissions")
            .select("contact_id")
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value

        let ids = rows.compactMap { $0.contactId }
        var seen = Set<UUID>()
        var unique: [UUID] = []
        for id in ids {
            if seen.insert(id).inserted {
                unique.append(id)
            }
        }
        return unique
    }
}

private struct CRMTaskPickFromAllContactsView: View {
    let contacts: [CRMContact]
    let isLoading: Bool
    let selectedContactId: UUID?
    let onPick: (CRMTaskContactPickerView.PickerResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if !isLoading, contacts.isEmpty {
                Text("暂无客户")
                    .foregroundStyle(EMTheme.ink2)
            }

            ForEach(filteredContacts) { c in
                Button {
                    onPick(.contact(c.id))
                    dismiss()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(crmContactTitle(c))
                                .foregroundStyle(EMTheme.ink)

                            if let subtitle = crmContactSubtitle(c), !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)
                                    .lineLimit(2)
                            }

                            if let meta = crmContactMetaLine(c), !meta.isEmpty {
                                Text(meta)
                                    .font(.caption2)
                                    .foregroundStyle(EMTheme.ink2)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if selectedContactId == c.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(EMTheme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
        .background(EMTheme.paper)
        .navigationTitle("客户")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索客户姓名/邮箱/电话/标签")
    }

    private var filteredContacts: [CRMContact] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return contacts }
        return contacts.filter { c in
            let hay = [c.fullName, c.email, c.phone, c.notes, (c.tags ?? []).joined(separator: " ")].joined(separator: " ")
            return hay.localizedCaseInsensitiveContains(q)
        }
    }

}
