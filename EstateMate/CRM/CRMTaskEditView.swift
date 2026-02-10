//
//  CRMTaskEditView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMTaskEditView: View {
    enum Mode: Equatable {
        case create(contactId: UUID?)
        case edit(taskId: UUID)

        var title: String {
            switch self {
            case .create: return "新增任务"
            case .edit: return "编辑任务"
            }
        }
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var title = ""
    @State private var notes = ""
    @State private var hasDue = false
    @State private var dueAt = Date()

    @State private var contacts: [CRMContact] = []
    @State private var isContactsLoading = false
    @State private var selectedContactId: UUID?

    private let service = CRMTasksService()
    private let crmService = CRMService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(mode.title, subtitle: "把跟进动作变成任务，避免忘记")

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    EMCard {
                        EMTextField(title: "标题", text: $title, prompt: "例如：给客户回电话")
                        EMTextField(title: "备注", text: $notes, prompt: "例如：问预算与区域偏好")

                        Divider().overlay(EMTheme.line)

                        HStack(spacing: 10) {
                            Text("客户")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(EMTheme.ink)

                            Spacer()

                            if isContactsLoading {
                                ProgressView().controlSize(.small)
                            }

                            Menu {
                                Button("不指定") { selectedContactId = nil }
                                Divider()
                                ForEach(contacts) { c in
                                    Button(contactDisplayName(c)) {
                                        selectedContactId = c.id
                                    }
                                }
                            } label: {
                                Text(selectedContactLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                                    .lineLimit(1)
                            }
                        }

                        Toggle(isOn: $hasDue) {
                            Text("设置截止时间")
                                .font(.subheadline)
                        }
                        .tint(EMTheme.accent)

                        if hasDue {
                            DatePicker("截止", selection: $dueAt)
                                .datePickerStyle(.compact)
                                .tint(EMTheme.accent)
                        }
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Text(isLoading ? "保存中…" : "保存")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading))
                    .disabled(isLoading)

                    Button {
                        dismiss()
                    } label: {
                        Text("取消")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())
                    .disabled(isLoading)

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: mode) {
            // Initialize selected contact from mode.
            if case let .create(contactId) = mode {
                selectedContactId = contactId
            }
            await loadIfNeeded()
            await loadContactsIfNeeded()
        }
        .onTapGesture {
            hideKeyboard()
        }
    }

    private func loadIfNeeded() async {
        guard case let .edit(taskId) = mode else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let t = try await service.getTask(id: taskId)
            title = t.title
            notes = t.notes
            selectedContactId = t.contactId
            if let due = t.dueAt {
                hasDue = true
                dueAt = due
            } else {
                hasDue = false
            }
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func loadContactsIfNeeded() async {
        if isContactsLoading { return }
        if !contacts.isEmpty { return }

        isContactsLoading = true
        defer { isContactsLoading = false }

        do {
            // MVP: load all contacts; later we can add search/paging.
            contacts = try await crmService.listContacts()
        } catch {
            // Non-blocking: task can still be saved without specifying a customer.
        }
    }

    private var selectedContactLabel: String {
        guard let selectedContactId else { return "不指定" }
        if let c = contacts.first(where: { $0.id == selectedContactId }) {
            return contactDisplayName(c)
        }
        return "已指定"
    }

    private func contactDisplayName(_ c: CRMContact) -> String {
        let n = c.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { return n }
        let e = c.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !e.isEmpty { return e }
        let p = c.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { return p }
        return "未命名客户"
    }

    private func save() async {
        hideKeyboard()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let due = hasDue ? dueAt : nil

        do {
            switch mode {
            case let .create(contactId):
                _ = try await service.createTask(CRMTaskInsert(contactId: selectedContactId ?? contactId, title: t, notes: n, dueAt: due))
                dismiss()

            case let .edit(taskId):
                _ = try await service.updateTask(id: taskId, patch: CRMTaskUpdate(contactId: selectedContactId, title: t, notes: n, dueAt: due, isDone: nil))
                dismiss()
            }
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        CRMTaskEditView(mode: .create(contactId: nil))
    }
}
