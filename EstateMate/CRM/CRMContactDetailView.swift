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
    @State private var isUpdatingStage = false

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
                            VStack(alignment: .leading, spacing: 8) {
                                Text("阶段")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)

                                stageTabs(current: contact.stage) { newStage in
                                    await updateStage(newStage)
                                }
                            }

                            Divider().overlay(EMTheme.line)
                            infoRow(label: "手机号", value: contact.phone)

                            Divider().overlay(EMTheme.line)
                            infoRow(label: "邮箱", value: contact.email)

                            Divider().overlay(EMTheme.line)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("感兴趣的地址")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)

                                let addresses = splitInterestedAddresses(contact.address)
                                if addresses.isEmpty {
                                    Text("—")
                                        .font(.body)
                                        .foregroundStyle(EMTheme.ink)
                                } else {
                                    FlowLayout(maxPerRow: 3, spacing: 8) {
                                        ForEach(addresses, id: \.self) { a in
                                            EMChip(text: a, isOn: true)
                                        }
                                    }
                                }
                            }

                            Divider().overlay(EMTheme.line)
                            infoRow(label: "备注", value: contact.notes)

                            Divider().overlay(EMTheme.line)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("标签")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)

                                let tags = contact.tags ?? []
                                if tags.isEmpty {
                                    Text("—")
                                        .font(.body)
                                        .foregroundStyle(EMTheme.ink)
                                } else {
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

    private func stageTabs(
        current: CRMContactStage,
        onSelect: @escaping (CRMContactStage) async -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CRMContactStage.allCases, id: \.self) { s in
                    Button {
                        guard !isUpdatingStage else { return }
                        guard s != current else { return }
                        Task { await onSelect(s) }
                    } label: {
                        EMChip(text: s.displayName, isOn: s == current)
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdatingStage)
                }

                if isUpdatingStage {
                    ProgressView()
                        .scaleEffect(0.9)
                        .padding(.leading, 4)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func updateStage(_ newStage: CRMContactStage) async {
        guard let existing = contact else { return }
        guard existing.stage != newStage else { return }

        isUpdatingStage = true
        errorMessage = nil
        defer { isUpdatingStage = false }

        // optimistic UI
        var optimistic = existing
        optimistic.stage = newStage
        optimistic.updatedAt = Date()
        contact = optimistic

        do {
            _ = try await service.updateContact(
                id: existing.id,
                patch: CRMContactUpdate(
                    fullName: nil,
                    phone: nil,
                    email: nil,
                    notes: nil,
                    tags: nil,
                    stage: newStage,
                    source: nil,
                    lastContactedAt: nil
                )
            )

            // re-fetch to keep server truth (updatedAt, etc.)
            contact = try await service.getContact(id: existing.id)
        } catch {
            errorMessage = "更新阶段失败：\(error.localizedDescription)"
            contact = existing
        }
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
