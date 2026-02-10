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

    private let service = CRMTasksService()

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
            await loadIfNeeded()
        }
        .onTapGesture {
            hideKeyboard()
        }
    }

    private func loadIfNeeded() async {
        // MVP: no getTask endpoint; we can just list & find later.
        // For now: best-effort load by selecting from listTasks(includeDone:true) and matching id.
        guard case let .edit(taskId) = mode else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let all = try await service.listTasks(includeDone: true)
            if let t = all.first(where: { $0.id == taskId }) {
                title = t.title
                notes = t.notes
                if let due = t.dueAt {
                    hasDue = true
                    dueAt = due
                } else {
                    hasDue = false
                }
            }
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
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
                _ = try await service.createTask(CRMTaskInsert(contactId: contactId, title: t, notes: n, dueAt: due))
                dismiss()

            case let .edit(taskId):
                _ = try await service.updateTask(id: taskId, patch: CRMTaskUpdate(contactId: nil, title: t, notes: n, dueAt: due, isDone: nil))
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
