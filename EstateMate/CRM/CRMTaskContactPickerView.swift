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
    @State private var events: [OpenHouseEvent] = []

    private let openHouse = OpenHouseService()

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

            ForEach(events) { e in
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
                        Text("进入该活动的客户列表")
                            .font(.caption)
                            .foregroundStyle(EMTheme.ink2)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(EMTheme.paper)
        .navigationTitle("活动")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .refreshable {
            await load(force: true)
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
}

private struct CRMTaskPickContactFromEventSubmissionsView: View {
    let event: OpenHouseEvent
    let selectedContactId: UUID?
    let onPick: (CRMTaskContactPickerView.PickerResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var contacts: [CRMContact] = []

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

            ForEach(contacts) { c in
                Button {
                    onPick(.contact(c.id))
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(contactLabel(c))
                                .foregroundStyle(EMTheme.ink)

                            if !c.email.isEmpty {
                                Text(c.email)
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)
                            } else if !c.phone.isEmpty {
                                Text(c.phone)
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)
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
        .task {
            await load()
        }
        .refreshable {
            await load(force: true)
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

    private func contactLabel(_ c: CRMContact) -> String {
        let n = c.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { return n }
        if !c.email.isEmpty { return c.email }
        if !c.phone.isEmpty { return c.phone }
        return "未命名客户"
    }
}

private struct CRMTaskPickFromAllContactsView: View {
    let contacts: [CRMContact]
    let isLoading: Bool
    let selectedContactId: UUID?
    let onPick: (CRMTaskContactPickerView.PickerResult) -> Void

    @Environment(\.dismiss) private var dismiss

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

            ForEach(contacts) { c in
                Button {
                    onPick(.contact(c.id))
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(contactLabel(c))
                                .foregroundStyle(EMTheme.ink)

                            if !c.email.isEmpty {
                                Text(c.email)
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)
                            } else if !c.phone.isEmpty {
                                Text(c.phone)
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)
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
    }

    private func contactLabel(_ c: CRMContact) -> String {
        let n = c.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { return n }
        if !c.email.isEmpty { return c.email }
        if !c.phone.isEmpty { return c.phone }
        return "未命名客户"
    }
}
