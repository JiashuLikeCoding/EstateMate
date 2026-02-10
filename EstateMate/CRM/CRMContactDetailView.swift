//
//  CRMContactDetailView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMContactDetailView: View {
    let contactId: UUID

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var contact: CRMContact?

    @State private var isEditPresented = false

    private let service = CRMService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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

                    if let contact {
                        EMSectionHeader(contact.fullName.isEmpty ? "（未命名）" : contact.fullName)

                        EMCard {
                            infoRow(label: "阶段", value: contact.stage.displayName)

                            Divider().overlay(EMTheme.line)
                            infoRow(label: "来源", value: contact.source.displayName)

                            let addresses = splitInterestedAddresses(contact.address)
                            if !addresses.isEmpty {
                                Divider().overlay(EMTheme.line)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("感兴趣的地址")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(EMTheme.ink2)
                                    FlowLayout(maxPerRow: 3, spacing: 8) {
                                        ForEach(addresses, id: \.self) { a in
                                            EMChip(text: a, isOn: true)
                                        }
                                    }
                                }
                            }

                            Divider().overlay(EMTheme.line)
                            infoRow(label: "备注", value: contact.notes)

                            if let tags = contact.tags, !tags.isEmpty {
                                Divider().overlay(EMTheme.line)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("标签")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(EMTheme.ink2)
                                    FlowLayout(maxPerRow: 99, spacing: 8) {
                                        ForEach(tags, id: \.self) { t in
                                            EMChip(text: t, isOn: true)
                                        }
                                    }
                                }
                            }
                        }

                        EMCard {
                            VStack(alignment: .leading, spacing: 0) {
                                NavigationLink {
                                    CRMContactActivitiesView(contactId: contactId)
                                } label: {
                                    linkRow(icon: "calendar", title: "参与的活动")
                                }
                                .buttonStyle(.plain)

                                Divider().overlay(EMTheme.line)

                                NavigationLink {
                                    CRMEmailLogsView(contactId: contactId)
                                } label: {
                                    linkRow(icon: "envelope", title: "来往的邮件")
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
        .navigationTitle("客户")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") {
                    isEditPresented = true
                }
                .disabled(contact == nil)
            }
        }
        .sheet(isPresented: $isEditPresented) {
            NavigationStack {
                CRMContactEditView(mode: .edit(contactId))
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
            contact = try await service.getContact(id: contactId)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(EMTheme.ink2)
            Text(value.isEmpty ? "—" : value)
                .font(.body)
                .foregroundStyle(EMTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linkRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(EMTheme.accent)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(EMTheme.accent.opacity(0.10))
                )

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(EMTheme.ink)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(EMTheme.ink2.opacity(0.7))
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func splitInterestedAddresses(_ raw: String) -> [String] {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return [] }

        let replaced = s
            .replacingOccurrences(of: "\n", with: ",")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "|", with: ",")
            .replacingOccurrences(of: "/", with: ",")
            .replacingOccurrences(of: "、", with: ",")

        return replaced
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
