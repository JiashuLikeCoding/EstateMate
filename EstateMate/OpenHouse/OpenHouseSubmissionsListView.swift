//
//  OpenHouseSubmissionsListView.swift
//  EstateMate
//

import SwiftUI

struct OpenHouseSubmissionsListView: View {
    @Environment(\.dismiss) private var dismiss

    private let service = DynamicFormService()

    let event: OpenHouseEventV2

    @State private var submissions: [SubmissionV2] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        EMScreen("已提交") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(event.title, subtitle: "已提交的访客登记")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    if isLoading {
                        EMCard {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    } else if submissions.isEmpty {
                        EMCard {
                            Text("暂无提交")
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.vertical, 10)
                        }
                    } else {
                        ForEach(submissions) { s in
                            EMCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(s.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(EMTheme.ink2)
                                        Spacer()
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(s.data.keys.sorted(), id: \.self) { k in
                                            HStack(alignment: .firstTextBaseline) {
                                                Text(k)
                                                    .font(.caption)
                                                    .foregroundStyle(EMTheme.ink2)
                                                    .frame(width: 90, alignment: .leading)
                                                Text(s.data[k] ?? "")
                                                    .font(.callout)
                                                    .foregroundStyle(EMTheme.ink)
                                                Spacer(minLength: 0)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
                    .foregroundStyle(EMTheme.ink2)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            submissions = try await service.listSubmissions(eventId: event.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
