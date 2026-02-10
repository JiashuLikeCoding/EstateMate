//
//  FormBuilderCanvasView.swift
//  EstateMate
//

import SwiftUI

struct FormBuilderCanvasView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: FormBuilderState
    private let service = DynamicFormService()

    /// If provided, shows a plus button attached to the "表单" card (right side).
    var addFieldAction: (() -> Void)? = nil

    /// Called after a successful save.
    var onSaved: (() -> Void)? = nil

    /// If provided, tapping a field (in list or preview) will request opening the editor UI (iPhone sheet).
    var onEditFieldRequested: (() -> Void)? = nil

    @State private var showSavedAlert: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let msg = state.errorMessage {
                    Text(msg)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                EMCard {
                    Text("表单信息")
                        .font(.headline)

                    EMTextField(title: "表单名称", text: $state.formName)
                }

                EMCard {
                    HStack(alignment: .center, spacing: 12) {
                        Text("表单")
                            .font(.headline)

                        Spacer()

                        Text("长按拖动排序")
                            .font(.caption)
                            .foregroundStyle(EMTheme.ink2)

                        if let addFieldAction {
                            Button(action: addFieldAction) {
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(EMTheme.accent))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("添加字段")
                        }
                    }

                    if state.fields.isEmpty {
                        Text("从字段库添加字段")
                            .foregroundStyle(EMTheme.ink2)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(state.fields.enumerated()), id: \.element.key) { idx, f in
                            Button {
                                selectField(key: f.key)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(f.label)
                                            .font(.headline)
                                            .foregroundStyle(EMTheme.ink)
                                        Text(summary(f))
                                            .font(.caption)
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                    Spacer()
                                    Image(systemName: state.selectedFieldKey == f.key ? "checkmark.circle.fill" : "chevron.right")
                                        .foregroundStyle(state.selectedFieldKey == f.key ? EMTheme.accent : EMTheme.ink2)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if idx != state.fields.count - 1 {
                                Divider().overlay(EMTheme.line)
                            }
                        }
                    }
                }

                // Preview should appear above the save button.
                if !state.fields.isEmpty {
                    previewCard
                }

                Button(state.isSaving ? "保存中..." : "保存表单") {
                    Task { await save() }
                }
                .buttonStyle(EMPrimaryButtonStyle(disabled: state.isSaving || state.formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .disabled(state.isSaving || state.formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .alert("已保存", isPresented: $showSavedAlert) {
                    Button("好的") {
                        if let onSaved {
                            onSaved()
                        } else {
                            dismiss()
                        }
                    }
                } message: {
                    Text("表单已保存")
                }

                Text("提示：点右侧“＋”添加字段，再点击表单预览或表单列表里的字段编辑属性")
                    .font(.footnote)
                    .foregroundStyle(EMTheme.ink2)

                Spacer(minLength: 20)
            }
            .padding(EMTheme.padding)
        }
    }

    private var previewCard: some View {
        EMCard {
            HStack(alignment: .firstTextBaseline) {
                Text("预览")
                    .font(.headline)

                Spacer()

                Text("单击字段即可编辑")
                    .font(.caption)
                    .foregroundStyle(EMTheme.ink2)
            }

            VStack(spacing: 10) {
                ForEach(state.fields) { f in
                    Button {
                        selectField(key: f.key)
                    } label: {
                        previewRow(field: f)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
    }

    private func previewRow(field f: FormField) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(f.label)
                .font(.callout)
                .foregroundStyle(EMTheme.ink)
                .frame(width: 86, alignment: .leading)

            Text(previewPlaceholder(for: f))
                .font(.callout)
                .foregroundStyle(EMTheme.ink2)

            Spacer(minLength: 0)

            if state.selectedFieldKey == f.key {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(EMTheme.accent)
            }
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
        .contentShape(Rectangle())
    }

    private func previewPlaceholder(for f: FormField) -> String {
        switch f.type {
        case .name:
            return "点击输入..."
        case .text:
            return "点击输入..."
        case .phone:
            return (f.phoneFormat ?? .plain) == .withCountryCode ? "+1 123456789" : "123456789"
        case .email:
            return "name@email.com"
        case .select:
            return (f.options?.first).map { "请选择（例如：\($0)）" } ?? "请选择..."
        }
    }

    private func selectField(key: String) {
        state.selectedFieldKey = key
        onEditFieldRequested?()
    }

    private func summary(_ f: FormField) -> String {
        let type: String = switch f.type {
        case .name: "姓名"
        case .text: "文本"
        case .phone: "手机号"
        case .email: "邮箱"
        case .select: "单选"
        }
        return "类型：\(type)  ·  \(f.required ? "必填" : "选填")"
    }

    private func save() async {
        state.isSaving = true
        defer { state.isSaving = false }

        do {
            for f in state.fields where f.type == .select {
                if (f.options ?? []).isEmpty {
                    throw NSError(domain: "FormBuilder", code: 1, userInfo: [NSLocalizedDescriptionKey: "单选字段 \"\(f.label)\" 需要选项"])
                }
            }

            let schema = FormSchema(version: 1, fields: state.fields)

            if let id = state.formId {
                _ = try await service.updateForm(id: id, name: state.formName, schema: schema)
            } else {
                let created = try await service.createForm(name: state.formName, schema: schema)
                state.formId = created.id
            }

            state.errorMessage = nil
            showSavedAlert = true
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
