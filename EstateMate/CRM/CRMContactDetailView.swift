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
                            infoRow(label: "手机号", value: contact.phone)
                            Divider().overlay(EMTheme.line)
                            infoRow(label: "邮箱", value: contact.email)
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
}
