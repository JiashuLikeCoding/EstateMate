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
    @State private var address = "" // 感兴趣的地址
    @State private var createdLocation = "" // 新增地点（自动）
    @State private var tagsText = "" // comma-separated

    @State private var isFillingLocation = false
    @State private var showLocationError = false
    @State private var locationErrorMessage: String?
    @State private var stage: CRMContactStage = .newLead
    @State private var source: CRMContactSource = .manual

    private let service = CRMService()
    private let locationService = LocationAddressService()

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

                        EMTextField(title: "感兴趣的地址", text: $address, prompt: "例如：Finch 地铁站附近 / 123 Main St")

                        EMLocationField(
                            title: "新增地点（自动）",
                            text: $createdLocation,
                            prompt: "点击右侧图标获取",
                            isLoading: isFillingLocation,
                            onFillFromCurrentLocation: {
                                hideKeyboard()
                                Task { await fillCreatedLocation() }
                            }
                        )
                        .alert("无法获取当前位置", isPresented: $showLocationError) {
                            Button("好的", role: .cancel) {}
                        } message: {
                            Text(locationErrorMessage ?? "请稍后重试")
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
            createdLocation = extractCreatedLocation(from: c.notes)
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

    private func fillCreatedLocation() async {
        isFillingLocation = true
        defer { isFillingLocation = false }
        do {
            let line = try await locationService.fillCurrentAddress()
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return }

            createdLocation = trimmed
            notes = upsertCreatedLocationNote(into: notes, locationLine: trimmed)
        } catch {
            locationErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showLocationError = true
        }
    }

    private func upsertCreatedLocationNote(into notes: String, locationLine: String) -> String {
        let prefix = "新增地点："
        let stamp = createdAtStamp()
        let newLine = "\(prefix)\(locationLine)（\(stamp)）"

        var lines = notes
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        lines.removeAll(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(prefix) })

        if lines.isEmpty {
            return newLine
        }

        // Put it on top for visibility.
        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines[0] = newLine
        } else {
            lines.insert(newLine, at: 0)
        }

        return lines.joined(separator: "\n")
    }

    private func extractCreatedLocation(from notes: String) -> String {
        let prefix = "新增地点："
        for raw in notes.split(separator: "\n") {
            let line = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix(prefix) else { continue }
            var rest = String(line.dropFirst(prefix.count))
            // Strip trailing full-width parentheses stamp if present.
            if let range = rest.range(of: "（", options: .backwards) {
                rest = String(rest[..<range.lowerBound])
            }
            return rest.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private func createdAtStamp() -> String {
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }
}

private struct EMLocationField: View {
    let title: String
    @Binding var text: String
    var prompt: String

    var isLoading: Bool
    var onFillFromCurrentLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(EMTheme.ink2)

            HStack(spacing: 10) {
                TextField(prompt, text: $text)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)

                Button {
                    onFillFromCurrentLocation()
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.callout.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(EMTheme.accent)
                .disabled(isLoading)
                .accessibilityLabel("使用当前位置")
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
    }
}

#Preview {
    NavigationStack {
        CRMContactEditView(mode: .create)
    }
}
