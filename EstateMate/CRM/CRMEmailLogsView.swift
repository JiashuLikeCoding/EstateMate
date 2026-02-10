//
//  CRMEmailLogsView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMEmailLogsView: View {
    let contactId: UUID

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var contact: CRMContact?

    @State private var logs: [CRMEmailLog] = []
    @State private var gmailMessages: [CRMGmailIntegrationService.ContactMessagesResponse.Item] = []

    @State private var isGmailLoading = false
    @State private var gmailError: String?

    @State private var isCreatePresented = false

    private let service = CRMEmailService()
    private let crmService = CRMService()
    private let gmail = CRMGmailIntegrationService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("来往的邮件", subtitle: "已支持从 Gmail 拉取最近往来（MVP：只展示，不落库）")

                    if let email = contact?.email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        EMCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Gmail 往来")
                                        .font(.headline)
                                        .foregroundStyle(EMTheme.ink)
                                    Spacer()
                                    if isGmailLoading { ProgressView().controlSize(.small) }
                                }

                                if let gmailError {
                                    Text(gmailError)
                                        .font(.subheadline)
                                        .foregroundStyle(.red)
                                }

                                if !gmailMessages.isEmpty {
                                    ForEach(gmailMessages) { m in
                                        NavigationLink {
                                            CRMGmailMessageDetailView(messageId: m.id, contactEmail: email)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(m.direction == "inbound" ? "收到" : "发出")
                                                    .font(.footnote.weight(.medium))
                                                    .foregroundStyle(EMTheme.accent)
                                                Spacer()
                                                Text(CRMGmailIntegrationService.formatMessageDate(dateHeader: m.date, internalDate: m.internalDate))
                                                    .font(.footnote)
                                                    .foregroundStyle(EMTheme.ink2)
                                                    .lineLimit(1)
                                            }

                                            Text(m.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（无主题）" : m.subject)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(EMTheme.ink)
                                                .lineLimit(2)

                                            if !m.snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                Text(m.snippet)
                                                    .font(.footnote)
                                                    .foregroundStyle(EMTheme.ink2)
                                                    .lineLimit(2)
                                            }
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        Divider().overlay(EMTheme.line)
                                    }
                                } else if !isGmailLoading {
                                    Text("暂无 Gmail 往来（或尚未同步到最近邮件）。")
                                        .font(.subheadline)
                                        .foregroundStyle(EMTheme.ink2)
                                }

                                // 自动刷新：不需要用户手动点按钮。
                                // 仍保留一个“立即刷新”用于排障/确认。
                                Button(isGmailLoading ? "加载中…" : "立即刷新") {
                                    Task { await loadGmailMessages(force: true) }
                                }
                                .buttonStyle(EMSecondaryButtonStyle())
                                .disabled(isGmailLoading)
                            }
                        }
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

                    // 如果已经有 Gmail 往来，就不再显示“暂无邮件记录”的空态卡片，避免误导。
                    if !isLoading, logs.isEmpty, errorMessage == nil, gmailMessages.isEmpty {
                        EMCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("暂无邮件记录")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)
                                Text("你可以点右上角“新增”把沟通要点记下来")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                            }
                        }
                    }

                    ForEach(logs) { log in
                        NavigationLink {
                            CRMEmailLogEditView(mode: .edit(logId: log.id, contactId: contactId))
                        } label: {
                            EMCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(log.direction.title)
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(EMTheme.accent)
                                        Spacer()
                                        Text(log.sentAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                                            .font(.footnote)
                                            .foregroundStyle(EMTheme.ink2)
                                    }

                                    Text(log.subject.isEmpty ? "（无主题）" : log.subject)
                                        .font(.headline)
                                        .foregroundStyle(EMTheme.ink)
                                        .lineLimit(2)

                                    if !log.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(log.body)
                                            .font(.subheadline)
                                            .foregroundStyle(EMTheme.ink2)
                                            .lineLimit(3)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("邮件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("新增") {
                    isCreatePresented = true
                }
            }
        }
        .sheet(isPresented: $isCreatePresented) {
            NavigationStack {
                CRMEmailLogEditView(mode: .create(contactId: contactId))
            }
        }
        .task {
            await reload()
            await loadGmailMessages(force: true)
        }
        .task {
            // Auto refresh loop while this view is on-screen.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25 * 1_000_000_000)
                await loadGmailMessages(force: false)
            }
        }
        .refreshable {
            await reload()
            await loadGmailMessages(force: true)
        }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            contact = try await crmService.getContact(id: contactId)
            logs = try await service.listLogs(contactId: contactId)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func loadGmailMessages(force: Bool) async {
        // 防抖：避免页面上多个 task/refresh 同时触发。
        if isGmailLoading { return }
        if !force, !gmailMessages.isEmpty { /* allow periodic refresh */ }

        gmailError = nil

        guard let email = contact?.email.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            return
        }

        isGmailLoading = true
        defer { isGmailLoading = false }

        do {
            let res = try await gmail.contactMessages(contactEmail: email, max: 20)
            gmailMessages = res.messages
        } catch {
            // 周期刷新时失败不刷屏；force 刷新才提示。
            if force {
                gmailError = "Gmail 加载失败：\(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    NavigationStack {
        CRMEmailLogsView(contactId: UUID())
    }
}
