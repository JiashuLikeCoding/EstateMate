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
    @State private var address = ""
    @State private var tagsText = "" // comma-separated
    @State private var stage: CRMContactStage = .newLead
    @State private var source: CRMContactSource = .manual

    private let service = CRMService()
    private let locationService = LocationAddressService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(mode.title, subtitle: "先做最小可用：姓名/电话/邮箱/地址/标签/备注")

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
                            HStack {
                                Text("地址")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)
                                Spacer()
                                Button {
                                    Task { await fillAddress() }
                                } label: {
                                    Text("一键获取")
                                        .font(.footnote.weight(.semibold))
                                }
                                .buttonStyle(.plain)
                            }
                            EMTextField(title: "", text: $address, prompt: "例如：123 Main St, Toronto, ON")
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
            address = c.address
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
                        address: address.trimmingCharacters(in: .whitespacesAndNewlines),
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
                        address: address.trimmingCharacters(in: .whitespacesAndNewlines),
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

    private func fillAddress() async {
        hideKeyboard()
        do {
            let line = try await locationService.fillCurrentAddress()
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                address = line
            }
        } catch {
            errorMessage = "获取地址失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        CRMContactEditView(mode: .create)
    }
}
