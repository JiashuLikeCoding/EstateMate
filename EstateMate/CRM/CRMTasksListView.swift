//
//  CRMTasksListView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMTasksListView: View {
    @State private var includeDone = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var tasks: [CRMTask] = []

    private let service = CRMTasksService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("待办任务", subtitle: "跟进提醒与记录")

                    EMCard {
                        Toggle(isOn: $includeDone) {
                            Text("显示已完成")
                                .font(.subheadline)
                        }
                        .tint(EMTheme.accent)
                    }

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

                    if !isLoading && tasks.isEmpty {
                        EMCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("暂无任务")
                                    .font(.headline)
                                Text("建议：把“今天需要联系谁”都做成任务，然后每天清空。").font(.caption).foregroundStyle(EMTheme.ink2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(tasks) { t in
                            CRMTaskCard(task: t) {
                                await toggleDone(task: t)
                            } onEdit: {
                                // Present edit via navigation
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("待办任务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CRMTaskEditView(mode: .create(contactId: nil))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task(id: includeDone) {
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
            tasks = try await service.listTasks(includeDone: includeDone)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func toggleDone(task: CRMTask) async {
        do {
            let updated = try await service.updateTask(id: task.id, patch: CRMTaskUpdate(contactId: task.contactId, title: nil, notes: nil, dueAt: nil, isDone: !task.isDone))
            if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
                tasks[idx] = updated
            }
            if !includeDone {
                tasks.removeAll { $0.isDone }
            }
        } catch {
            errorMessage = "更新失败：\(error.localizedDescription)"
        }
    }
}

private struct CRMTaskCard: View {
    let task: CRMTask
    let onToggle: () async -> Void
    let onEdit: () -> Void

    var body: some View {
        EMCard {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    Task { await onToggle() }
                } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isDone ? EMTheme.accent : EMTheme.ink2)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title.isEmpty ? "（未命名任务）" : task.title)
                        .font(.headline)
                        .strikethrough(task.isDone)

                    if let dueAt = task.dueAt {
                        Text("截止：\(CRMTaskDate.shortDateTime.string(from: dueAt))")
                            .font(.caption)
                            .foregroundStyle(EMTheme.ink2)
                    }

                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.caption)
                            .foregroundStyle(EMTheme.ink2)
                            .lineLimit(2)
                    }
                }
                Spacer()

                NavigationLink {
                    CRMTaskEditView(mode: .edit(taskId: task.id))
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(EMTheme.ink2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

enum CRMTaskDate {
    static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}

#Preview {
    NavigationStack {
        CRMTasksListView()
    }
}
