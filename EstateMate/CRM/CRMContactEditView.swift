//
//  CRMContactEditView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMContactEditView: View {
    enum Mode: Equatable {
        case create
        case edit(UUID)

        var title: String {
            switch self {
            case .create: return "新增客户"
            case .edit: return "编辑客户"
            }
        }
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""

    // Interested addresses (chips)
    @State private var addressInput = ""
    @State private var interestedAddresses: [String] = []

    @State private var tagsText = "" // comma-separated
    @State private var stage: CRMContactStage = .newLead
    @State private var source: CRMContactSource = .manual

    private let service = CRMService()
    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(mode.title, subtitle: "先做最小可用：姓名/电话/邮箱/感兴趣地址/标签/备注")

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    EMCard {
                        EMTextField(title: "姓名", text: $fullName, prompt: "例如：王小明")
                        EMTextField(title: "手机号", text: $phone, prompt: "例如：13800000000", keyboard: .phonePad)
                        EMTextField(title: "邮箱", text: $email, prompt: "例如：name@email.com", keyboard: .emailAddress)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("感兴趣的地址")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            if !interestedAddresses.isEmpty {
                                FlowLayout(maxPerRow: 3, spacing: 8) {
                                    ForEach(interestedAddresses, id: \.self) { a in
                                        InterestedAddressChip(text: a) {
                                            removeInterestedAddress(a)
                                        }
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                TextField("例如：Finch 地铁站附近 / 123 Main St", text: $addressInput)
                                    .textInputAutocapitalization(.sentences)
                                    .autocorrectionDisabled(false)

                                Button {
                                    addInterestedAddressFromInput()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.callout.weight(.semibold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(EMTheme.accent)
                                .disabled(addressInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityLabel("添加感兴趣地址")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                    .fill(EMTheme.paper2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                    .stroke(EMTheme.line, lineWidth: 1)
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("阶段")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            Picker("阶段", selection: $stage) {
                                ForEach(CRMContactStage.allCases, id: \.self) { s in
                                    Text(s.displayName).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("来源")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            Picker("来源", selection: $source) {
                                ForEach(CRMContactSource.allCases, id: \.self) { s in
                                    Text(s.displayName).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        EMTextField(title: "标签（逗号分隔）", text: $tagsText, prompt: "例如：学区房, 投资")
                        EMTextField(title: "备注", text: $notes, prompt: "例如：喜欢南向三居")
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
        guard case let .edit(id) = mode else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let c = try await service.getContact(id: id)
            fullName = c.fullName
            phone = c.phone
            email = c.email
            notes = c.notes
            interestedAddresses = splitInterestedAddresses(c.address)
            tagsText = (c.tags ?? []).joined(separator: ", ")
            stage = c.stage
            source = c.source
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func save() async {
        hideKeyboard()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let tags = tagsText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            switch mode {
            case .create:
                _ = try await service.createOrMergeContact(
                    CRMContactInsert(
                        fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                        phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                        address: joinInterestedAddresses(interestedAddresses),
                        tags: tags.isEmpty ? nil : tags,
                        stage: stage,
                        source: source,
                        lastContactedAt: nil
                    )
                )
                dismiss()

            case let .edit(id):
                _ = try await service.updateContact(
                    id: id,
                    patch: CRMContactUpdate(
                        fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                        phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                        address: joinInterestedAddresses(interestedAddresses),
                        tags: tags.isEmpty ? [] : tags,
                        stage: stage,
                        source: source,
                        lastContactedAt: nil
                    )
                )
                dismiss()
            }
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func addInterestedAddressFromInput() {
        let trimmed = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Support quick paste with separators.
        let parts = splitInterestedAddresses(trimmed)
        for p in parts {
            if !interestedAddresses.contains(p) {
                interestedAddresses.append(p)
            }
        }

        addressInput = ""
    }

    private func removeInterestedAddress(_ a: String) {
        interestedAddresses.removeAll(where: { $0 == a })
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

    private func joinInterestedAddresses(_ items: [String]) -> String {
        items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        CRMContactEditView(mode: .create)
    }
}

private struct InterestedAddressChip: View {
    let text: String
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            EMChip(text: text, isOn: true)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EMTheme.ink2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("移除")
        }
    }
}
