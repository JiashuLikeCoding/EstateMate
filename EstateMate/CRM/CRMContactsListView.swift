//
//  CRMContactsListView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMContactsListView: View {
    @State private var searchText: String = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var contacts: [CRMContact] = []

    @State private var isSelecting = false
    @State private var selectedIds = Set<UUID>()

    @State private var showFilterSheet = false
    @State private var filter = ContactsFilter()

    @State private var showDeleteConfirm = false
    @State private var showBulkEditSheet = false

    private let service = CRMService()

    struct ContactsFilter: Equatable {
        var stage: CRMContactStage? = nil
        var source: CRMContactSource? = nil
        var mustHaveEmail: Bool = false
        var mustHavePhone: Bool = false
        var tagContains: String = ""

        var isActive: Bool {
            stage != nil || source != nil || mustHaveEmail || mustHavePhone || !tagContains.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("客户列表", subtitle: "搜索、查看与编辑")

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

                    if !isLoading && filteredContacts.isEmpty {
                        EMCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无客户" : "没有匹配的客户")
                                    .font(.headline)
                                Text("你可以先从开放日的提交里转入客户（后续做），或手动新增。")
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(filteredContacts) { c in
                            if isSelecting {
                                EMCard {
                                    Button {
                                        toggleSelect(c.id)
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: selectedIds.contains(c.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedIds.contains(c.id) ? EMTheme.accent : EMTheme.ink2)
                                                .font(.system(size: 18, weight: .semibold))
                                                .padding(.top, 2)

                                            CRMContactCardContent(contact: c)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                NavigationLink {
                                    CRMContactDetailView(contactId: c.id)
                                } label: {
                                    CRMContactCard(contact: c)
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
        .navigationTitle("客户列表")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索姓名/手机号/邮箱/标签")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.snappy) {
                        isSelecting.toggle()
                        if !isSelecting { selectedIds = [] }
                    }
                } label: {
                    Text(isSelecting ? "完成" : "选择")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CRMGmailConnectView()
                } label: {
                    Image(systemName: "envelope")
                }
                .disabled(isSelecting)
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CRMAIContactImportView()
                } label: {
                    Image(systemName: "sparkles")
                }
                .disabled(isSelecting)
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CRMContactEditView(mode: .create)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isSelecting)
            }
        }
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
        .sheet(isPresented: $showFilterSheet) {
            CRMContactsFilterSheet(filter: $filter)
        }
        .confirmationDialog(
            "删除客户",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除已选（\(selectedIds.count)）", role: .destructive) {
                Task { await deleteSelected() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复，请确认。")
        }
        .sheet(isPresented: $showBulkEditSheet) {
            CRMBulkEditContactsView(selectedCount: selectedIds.count) { patch in
                Task { await bulkEditSelected(patch) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                bulkActionBar
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }

    private var filteredContacts: [CRMContact] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagQ = filter.tagContains.trimmingCharacters(in: .whitespacesAndNewlines)

        return contacts.filter { c in
            if let stage = filter.stage, c.stage != stage { return false }
            if let source = filter.source, c.source != source { return false }
            if filter.mustHaveEmail, c.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            if filter.mustHavePhone, c.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            if !tagQ.isEmpty {
                let tags = (c.tags ?? []).joined(separator: " ")
                if !tags.localizedCaseInsensitiveContains(tagQ) { return false }
            }

            if q.isEmpty { return true }
            let hay = [c.fullName, c.phone, c.email, c.notes, (c.tags ?? []).joined(separator: " ")].joined(separator: " ")
            return hay.localizedCaseInsensitiveContains(q)
        }
    }

    private var bulkActionBar: some View {
        EMCard {
            HStack(spacing: 10) {
                Button {
                    // toggle all for current filter result
                    let ids = Set(filteredContacts.map { $0.id })
                    if selectedIds.isSuperset(of: ids) {
                        selectedIds.subtract(ids)
                    } else {
                        selectedIds.formUnion(ids)
                    }
                } label: {
                    Text("全选/取消")
                }
                .buttonStyle(EMSecondaryButtonStyle())

                Spacer()

                Button {
                    showBulkEditSheet = true
                } label: {
                    Text("修改")
                }
                .buttonStyle(EMSecondaryButtonStyle())
                .disabled(selectedIds.isEmpty)

                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("删除")
                }
                .buttonStyle(EMPrimaryButtonStyle(disabled: selectedIds.isEmpty))
                .disabled(selectedIds.isEmpty)
            }
        }
        .padding(.horizontal, EMTheme.padding)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(EMTheme.paper)
    }

    private func toggleSelect(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func deleteSelected() async {
        hideKeyboard()
        let ids = Array(selectedIds)
        guard !ids.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            for id in ids {
                try await service.deleteContact(id: id)
            }
            selectedIds = []
            isSelecting = false
            await reload()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    private func bulkEditSelected(_ patch: CRMBulkEditContactsView.Patch) async {
        hideKeyboard()
        let ids = Array(selectedIds)
        guard !ids.isEmpty else { return }

        let newTag = patch.addTag.trimmingCharacters(in: .whitespacesAndNewlines)
        let appendNote = patch.appendToNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            for id in ids {
                guard let existing = contacts.first(where: { $0.id == id }) else { continue }

                var mergedTags = existing.tags ?? []
                if !newTag.isEmpty, !mergedTags.contains(newTag) {
                    mergedTags.append(newTag)
                }

                var notes = existing.notes
                if !appendNote.isEmpty {
                    if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        notes = appendNote
                    } else {
                        notes += "\n" + appendNote
                    }
                }

                _ = try await service.updateContact(
                    id: id,
                    patch: CRMContactUpdate(
                        fullName: nil,
                        phone: nil,
                        email: nil,
                        notes: notes == existing.notes ? nil : notes,
                        tags: mergedTags == (existing.tags ?? []) ? nil : mergedTags,
                        stage: patch.stage,
                        source: patch.source,
                        lastContactedAt: nil
                    )
                )
            }

            selectedIds = []
            isSelecting = false
            await reload()
        } catch {
            errorMessage = "批量修改失败：\(error.localizedDescription)"
        }
    }

    private func reload() async {
        hideKeyboard()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            contacts = try await service.listContacts()
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
}

private struct CRMContactsFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: CRMContactsListView.ContactsFilter

    var body: some View {
        NavigationStack {
            EMScreen {
                List {
                    Section("阶段") {
                        Picker("阶段", selection: Binding(get: {
                            filter.stage ?? CRMContactStage.newLead
                        }, set: { newValue in
                            filter.stage = newValue
                        })) {
                            Text("（不限制）").tag(CRMContactStage.newLead)
                            ForEach(CRMContactStage.allCases, id: \.self) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                        Button("清除阶段（不限制）") { filter.stage = nil }
                            .foregroundStyle(EMTheme.ink2)
                    }

                    Section("来源") {
                        Picker("来源", selection: Binding(get: {
                            filter.source ?? CRMContactSource.manual
                        }, set: { newValue in
                            filter.source = newValue
                        })) {
                            Text("（不限制）").tag(CRMContactSource.manual)
                            ForEach(CRMContactSource.allCases, id: \.self) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                        Button("清除来源（不限制）") { filter.source = nil }
                            .foregroundStyle(EMTheme.ink2)
                    }

                    Section("条件") {
                        Toggle("必须有邮箱", isOn: $filter.mustHaveEmail)
                        Toggle("必须有电话", isOn: $filter.mustHavePhone)

                        HStack {
                            Text("标签包含")
                            Spacer()
                            TextField("例如：高意向", text: $filter.tagContains)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }

                    Section {
                        Button("清空所有筛选") {
                            filter = .init()
                        }
                        .foregroundStyle(.red)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(EMTheme.paper)
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct CRMContactCard: View {
    let contact: CRMContact

    var body: some View {
        EMCard {
            CRMContactCardContent(contact: contact)
        }
    }
}

private struct CRMContactCardContent: View {
    let contact: CRMContact

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(contact.fullName.isEmpty ? "（未命名）" : contact.fullName)
                    .font(.headline)
                    .foregroundStyle(EMTheme.ink)
                Spacer()
                Text(CRMDate.shortDateTime.string(from: contact.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(EMTheme.ink2)
            }

            HStack(spacing: 8) {
                EMChip(text: contact.stage.displayName, isOn: true)
                EMChip(text: contact.source.displayName, isOn: false)
                Spacer()
                if let dt = contact.lastContactedAt {
                    Text("最近联系：\(CRMDate.shortDate.string(from: dt))")
                        .font(.caption2)
                        .foregroundStyle(EMTheme.ink2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if !contact.phone.isEmpty {
                    Text(contact.phone)
                        .font(.subheadline)
                        .foregroundStyle(EMTheme.ink2)
                }
                if !contact.email.isEmpty {
                    Text(contact.email)
                        .font(.caption)
                        .foregroundStyle(EMTheme.ink2)
                }
            }

            if let tags = contact.tags, !tags.isEmpty {
                FlowLayout(maxPerRow: 99, spacing: 8) {
                    ForEach(tags, id: \.self) { t in
                        EMChip(text: t, isOn: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum CRMDate {
    static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()
}

#Preview {
    NavigationStack {
        CRMContactsListView()
    }
}
