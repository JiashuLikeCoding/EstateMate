//
//  CRMContactsListView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMContactsListView: View {
    struct ContactNavTarget: Identifiable, Equatable, Hashable {
        let id: UUID
    }

    @State private var searchText: String = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var contacts: [CRMContact] = []

    // Open (not-done) tasks grouped by contact.
    @State private var openTasksByContactId: [UUID: [CRMTask]] = [:]

    @State private var isSelecting = false
    @State private var selectedIds = Set<UUID>()

    // 筛选功能暂时移除（后续再加）
    // @State private var showFilterSheet = false
    // @State private var filter = ContactsFilter()
    // @State private var participatedContactIds: Set<UUID>? = nil

    @State private var showDeleteConfirm = false
    @State private var showBulkEditSheet = false

    @State private var navigateToContact: ContactNavTarget? = nil

    private let service = CRMService()
    private let tasksService = CRMTasksService()

    struct ContactsFilter: Equatable {
        var stage: CRMContactStage? = nil
        var source: CRMContactSource? = nil

        /// created_at range (inclusive)
        var createdFrom: Date? = nil
        var createdTo: Date? = nil

        /// event participation filter
        var participatedEventId: UUID? = nil

        var mustHaveEmail: Bool = false
        var mustHavePhone: Bool = false

        /// address filters
        var addressContains: String = ""
        var mustHaveAddress: Bool = false

        /// tag filters
        var tagContains: String = ""
        var selectedTags: Set<String> = []

        var isActive: Bool {
            stage != nil ||
            source != nil ||
            createdFrom != nil ||
            createdTo != nil ||
            participatedEventId != nil ||
            mustHaveEmail ||
            mustHavePhone ||
            mustHaveAddress ||
            !addressContains.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !tagContains.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !selectedTags.isEmpty
        }
    }

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerRow

                    searchRow

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
                                    HStack(alignment: .top, spacing: 10) {
                                        Button {
                                            toggleSelect(c.id)
                                        } label: {
                                            Image(systemName: selectedIds.contains(c.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedIds.contains(c.id) ? EMTheme.accent : EMTheme.ink2)
                                                .font(.system(size: 18, weight: .semibold))
                                                .padding(.top, 2)
                                        }
                                        .buttonStyle(.plain)

                                        CRMContactCardContent(contact: c, tasks: openTasksByContactId[c.id] ?? [])
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        toggleSelect(c.id)
                                    }
                                }
                            } else {
                                EMCard {
                                    CRMContactCardContent(contact: c, tasks: openTasksByContactId[c.id] ?? [])
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    navigateToContact = ContactNavTarget(id: c.id)
                                }
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
        .navigationDestination(item: $navigateToContact) { target in
            CRMContactDetailView(contactId: target.id)
        }
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
        // 筛选 sheet 暂时移除（后续再加）
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

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("客户列表")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(EMTheme.ink)
                Text("搜索、查看与编辑")
                    .font(.caption)
                    .foregroundStyle(EMTheme.ink2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.snappy) {
                        isSelecting.toggle()
                        if !isSelecting { selectedIds = [] }
                    }
                } label: {
                    Text(isSelecting ? "完成" : "选择")
                        .font(.subheadline.weight(.semibold))
                }

                NavigationLink {
                    CRMGmailConnectView()
                } label: {
                    Image(systemName: "envelope")
                }
                .disabled(isSelecting)

                NavigationLink {
                    CRMAIContactImportView()
                } label: {
                    Image(systemName: "sparkles")
                }
                .disabled(isSelecting)

                NavigationLink {
                    CRMContactEditView(mode: .create)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isSelecting)
            }
            .foregroundStyle(EMTheme.ink)
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    private var searchRow: some View {
        EMCard {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(EMTheme.ink2)

                TextField("搜索姓名/标签/地址", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { hideKeyboard() }

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        searchText = ""
                        hideKeyboard()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(EMTheme.ink2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredContacts: [CRMContact] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return contacts }

        return contacts.filter { c in
            let hay = [
                c.fullName,
                c.phone,
                c.email,
                c.address,
                c.notes,
                (c.tags ?? []).joined(separator: " ")
            ].joined(separator: " ")

            return hay.localizedCaseInsensitiveContains(q)
        }
    }

    private var allTags: [String] {
        let set = Set(contacts.flatMap { $0.tags ?? [] })
        return set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
            async let contactsTask = service.listContacts()
            async let tasksTask = tasksService.listTasks(includeDone: false)

            contacts = try await contactsTask

            let tasks = (try? await tasksTask) ?? []
            var byId: [UUID: [CRMTask]] = [:]
            for t in tasks {
                guard let cid = t.contactId else { continue }
                byId[cid, default: []].append(t)
            }
            openTasksByContactId = byId
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
}

private struct CRMContactsFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: CRMContactsListView.ContactsFilter
    let allTags: [String]
    let onChangeParticipatedEvent: (_ eventId: UUID?) -> Void

    @State private var showEventPicker = false

    var body: some View {
        NavigationStack {
            EMScreen {
                List {
                    Section("添加时间") {
                        DatePicker(
                            "开始日期",
                            selection: Binding(get: {
                                filter.createdFrom ?? Date()
                            }, set: { v in
                                filter.createdFrom = v
                            }),
                            displayedComponents: .date
                        )
                        .opacity(filter.createdFrom == nil ? 0.45 : 1)

                        Button(filter.createdFrom == nil ? "设置开始日期" : "清除开始日期") {
                            if filter.createdFrom == nil {
                                filter.createdFrom = Date()
                            } else {
                                filter.createdFrom = nil
                            }
                        }
                        .foregroundStyle(EMTheme.ink2)

                        DatePicker(
                            "结束日期",
                            selection: Binding(get: {
                                filter.createdTo ?? Date()
                            }, set: { v in
                                filter.createdTo = v
                            }),
                            displayedComponents: .date
                        )
                        .opacity(filter.createdTo == nil ? 0.45 : 1)

                        Button(filter.createdTo == nil ? "设置结束日期" : "清除结束日期") {
                            if filter.createdTo == nil {
                                filter.createdTo = Date()
                            } else {
                                filter.createdTo = nil
                            }
                        }
                        .foregroundStyle(EMTheme.ink2)

                        Button("最近 7 天") {
                            filter.createdFrom = Calendar.current.date(byAdding: .day, value: -7, to: Date())
                            filter.createdTo = Date()
                        }
                        .foregroundStyle(EMTheme.ink2)

                        Button("最近 30 天") {
                            filter.createdFrom = Calendar.current.date(byAdding: .day, value: -30, to: Date())
                            filter.createdTo = Date()
                        }
                        .foregroundStyle(EMTheme.ink2)
                    }

                    Section("参与的活动") {
                        Button {
                            showEventPicker = true
                        } label: {
                            HStack {
                                Text("活动")
                                Spacer()
                                Text(filter.participatedEventId == nil ? "不限制" : "已选择")
                                    .foregroundStyle(EMTheme.ink2)
                            }
                        }

                        if filter.participatedEventId != nil {
                            Button("清除活动筛选") {
                                filter.participatedEventId = nil
                                onChangeParticipatedEvent(nil)
                            }
                            .foregroundStyle(EMTheme.ink2)
                        }
                    }

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

                    Section("感兴趣的地址") {
                        HStack {
                            Text("地址包含")
                            Spacer()
                            TextField("例如：Finch / 50 Morecambe", text: $filter.addressContains)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.sentences)
                                .autocorrectionDisabled(false)
                        }

                        Button(filter.addressContains.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "快速：清空" : "清除地址包含") {
                            filter.addressContains = ""
                        }
                        .foregroundStyle(EMTheme.ink2)
                    }

                    Section("标签") {
                        HStack {
                            Text("标签包含")
                            Spacer()
                            TextField("例如：高意向", text: $filter.tagContains)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        if !allTags.isEmpty {
                            NavigationLink {
                                CRMContactsTagsPickerView(allTags: allTags, selected: $filter.selectedTags)
                            } label: {
                                HStack {
                                    Text("选择标签")
                                    Spacer()
                                    Text(filter.selectedTags.isEmpty ? "不限" : "已选 \(filter.selectedTags.count)")
                                        .foregroundStyle(EMTheme.ink2)
                                }
                            }
                        }
                    }

                    Section("条件") {
                        Toggle("必须有邮箱", isOn: $filter.mustHaveEmail)
                        Toggle("必须有电话", isOn: $filter.mustHavePhone)
                        Toggle("必须有感兴趣地址", isOn: $filter.mustHaveAddress)
                    }

                    Section {
                        Button("清空所有筛选") {
                            filter = .init()
                            onChangeParticipatedEvent(nil)
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
            .sheet(isPresented: $showEventPicker) {
                CRMContactsEventPickerView(currentEventId: filter.participatedEventId) { ev in
                    filter.participatedEventId = ev?.id
                    onChangeParticipatedEvent(ev?.id)
                }
            }
        }
    }
}

private struct CRMContactsTagsPickerView: View {
    let allTags: [String]
    @Binding var selected: Set<String>

    var body: some View {
        List {
            ForEach(allTags, id: \.self) { t in
                Button {
                    if selected.contains(t) {
                        selected.remove(t)
                    } else {
                        selected.insert(t)
                    }
                } label: {
                    HStack {
                        Text(t)
                        Spacer()
                        if selected.contains(t) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(EMTheme.accent)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(EMTheme.paper)
        .navigationTitle("选择标签")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        let start = Calendar.current.startOfDay(for: self)
        return Calendar.current.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? self
    }
}

private struct CRMContactCardContent: View {
    let contact: CRMContact
    let tasks: [CRMTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(contact.fullName.isEmpty ? "（未命名）" : contact.fullName)
                    .font(.headline)
                    .foregroundStyle(EMTheme.ink)

                EMChip(text: contact.stage.displayName, isOn: true)

                Spacer()
                Text(CRMDate.shortDateTime.string(from: contact.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(EMTheme.ink2)
            }

            if !contact.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("电话：\(contact.phone)")
                    .font(.caption2)
                    .foregroundStyle(EMTheme.ink2)
            }

            if !contact.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("邮箱：\(contact.email)")
                    .font(.caption2)
                    .foregroundStyle(EMTheme.ink2)
            }

            if let dt = contact.lastContactedAt {
                Text("最近联系：\(CRMDate.shortDate.string(from: dt))")
                    .font(.caption2)
                    .foregroundStyle(EMTheme.ink2)
            }

            let addresses = splitInterestedAddresses(contact.address)
            if !addresses.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("感兴趣的地址：")
                        .font(.caption2)
                        .foregroundStyle(EMTheme.ink2)
                    FlowLayout(maxPerRow: 3, spacing: 8) {
                        ForEach(addresses, id: \.self) { a in
                            EMChip(text: a, isOn: false)
                        }
                    }
                }
            }

            if let tags = contact.tags, !tags.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("标签：")
                        .font(.caption2)
                        .foregroundStyle(EMTheme.ink2)
                    FlowLayout(maxPerRow: 99, spacing: 8) {
                        ForEach(tags, id: \.self) { t in
                            EMChip(text: t, isOn: true)
                        }
                    }
                }
            }

            let open = tasks.filter { !$0.isDone }
            if !open.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("代办：")
                        .font(.caption2)
                        .foregroundStyle(EMTheme.ink2)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(open.prefix(2)).indices, id: \.self) { idx in
                            let t = open[idx]
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(EMTheme.ink2)

                                Text(t.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（未命名任务）" : t.title)
                                    .font(.caption2)
                                    .foregroundStyle(EMTheme.ink)
                                    .lineLimit(1)

                                if let due = t.dueAt {
                                    Text(due.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundStyle(EMTheme.ink2)
                                }

                                Spacer(minLength: 0)
                            }
                        }

                        if open.count > 2 {
                            Text("还有 \(open.count - 2) 条…")
                                .font(.caption2)
                                .foregroundStyle(EMTheme.ink2)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
