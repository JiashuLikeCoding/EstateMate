//
//  CRMEmailLogEditView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMEmailLogEditView: View {
    enum Mode: Equatable {
        case create(contactId: UUID)
        case edit(logId: UUID, contactId: UUID)

        var title: String {
            switch self {
            case .create: return "新增邮件记录"
            case .edit: return "编辑邮件记录"
            }
        }

        var contactId: UUID {
            switch self {
            case let .create(contactId): return contactId
            case let .edit(_, contactId): return contactId
            }
        }

        var logId: UUID? {
            switch self {
            case .create: return nil
            case let .edit(logId, _): return logId
            }
        }
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var direction: CRMEmailDirection = .outbound
    @State private var subject = ""
    @State private var bodyText = ""

    @State private var hasSentAt = true
    @State private var sentAt = Date()

    private let service = CRMEmailService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(mode.title, subtitle: "记录沟通要点，后续可做提醒/跟进")

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("方向", selection: $direction) {
                                ForEach(CRMEmailDirection.allCases, id: \.self) { d in
                                    Text(d.title).tag(d)
                                }
                            }
                            .pickerStyle(.segmented)

                            EMTextField(title: "主题", text: $subject, prompt: "例如：感谢来访 + 补充资料")
                            EMTextField(title: "内容", text: $bodyText, prompt: "例如：客户预算/区域偏好/下一步动作")

                            Toggle(isOn: $hasSentAt) {
                                Text("记录时间")
                                    .font(.subheadline)
                            }
                            .tint(EMTheme.accent)

                            if hasSentAt {
                                DatePicker("时间", selection: $sentAt)
                                    .datePickerStyle(.compact)
                                    .tint(EMTheme.accent)
                            }
                        }
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Text(isLoading ? "保存中…" : "保存")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading))
                    .disabled(isLoading)

                    if mode.logId != nil {
                        Button(role: .destructive) {
                            Task { await delete() }
                        } label: {
                            Text("删除")
                        }
                        .buttonStyle(EMSecondaryButtonStyle())
                        .disabled(isLoading)
                    }

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
        guard let logId = mode.logId else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // MVP: reuse list and find (small per-contact list). Can be replaced by getLog later.
            let all = try await service.listLogs(contactId: mode.contactId)
            if let l = all.first(where: { $0.id == logId }) {
                direction = l.direction
                subject = l.subject
                bodyText = l.body
                if let s = l.sentAt {
                    hasSentAt = true
                    sentAt = s
                } else {
                    hasSentAt = false
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

        let s = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let at = hasSentAt ? sentAt : nil

        do {
            switch mode {
            case let .create(contactId):
                _ = try await service.createLog(CRMEmailLogInsert(contactId: contactId, direction: direction, subject: s, body: b, sentAt: at))
                dismiss()

            case let .edit(logId, _):
                _ = try await service.updateLog(id: logId, patch: CRMEmailLogUpdate(direction: direction, subject: s, body: b, sentAt: at))
                dismiss()
            }
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func delete() async {
        guard let logId = mode.logId else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await service.deleteLog(id: logId)
            dismiss()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        CRMEmailLogEditView(mode: .create(contactId: UUID()))
    }
}
