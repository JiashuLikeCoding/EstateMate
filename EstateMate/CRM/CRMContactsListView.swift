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

    private let service = CRMService()

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
                            NavigationLink {
                                CRMContactDetailView(contactId: c.id)
                            } label: {
                                CRMContactCard(contact: c)
                            }
                            .buttonStyle(.plain)
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
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CRMGmailConnectView()
                } label: {
                    Image(systemName: "envelope")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CRMContactEditView(mode: .create)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
        .onTapGesture {
            hideKeyboard()
        }
    }

    private var filteredContacts: [CRMContact] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return contacts }
        return contacts.filter { c in
            let hay = [c.fullName, c.phone, c.email, c.notes, (c.tags ?? []).joined(separator: " ")].joined(separator: " ")
            return hay.localizedCaseInsensitiveContains(q)
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

private struct CRMContactCard: View {
    let contact: CRMContact

    var body: some View {
        EMCard {
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
