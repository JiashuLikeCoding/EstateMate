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
    @State private var logs: [CRMEmailLog] = []

    @State private var isCreatePresented = false

    private let service = CRMEmailService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("来往的邮件", subtitle: "先做“手动记录”，后续可以接 Gmail/Outlook")

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

                    if !isLoading, logs.isEmpty, errorMessage == nil {
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
            logs = try await service.listLogs(contactId: contactId)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        CRMEmailLogsView(contactId: UUID())
    }
}
