//
//  FormBuilderCanvasView.swift
//  EstateMate
//

import SwiftUI

struct FormBuilderCanvasView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: FormBuilderState
    private let service = DynamicFormService()

    @State private var isPreviewPresented: Bool = false

    /// If provided, shows a plus button attached to the "表单" card (right side).
    var addFieldAction: (() -> Void)? = nil

    /// Called after a successful save.
    var onSaved: (() -> Void)? = nil

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
                                state.selectedFieldKey = f.key
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

                Text("提示：点右侧“＋”添加字段，再点击表单里的字段编辑属性")
                    .font(.footnote)
                    .foregroundStyle(EMTheme.ink2)
            }
            .padding(EMTheme.padding)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPreviewPresented = true
                } label: {
                    Image(systemName: "eye")
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(EMTheme.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("预览")
                .disabled(state.fields.isEmpty)
                .opacity(state.fields.isEmpty ? 0.4 : 1)
            }
        }
        .sheet(isPresented: $isPreviewPresented) {
            NavigationStack {
                FormPreviewView(formName: state.formName, fields: state.fields)
            }
        }
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
