//
//  FormBuilderCanvasView.swift
//  EstateMate
//

import SwiftUI

struct FormBuilderCanvasView: View {
    @EnvironmentObject var state: FormBuilderState
    private let service = DynamicFormService()

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
                    HStack {
                        Text("画布")
                            .font(.headline)
                        Spacer()
                        Text("长按拖动排序")
                            .font(.caption)
                            .foregroundStyle(EMTheme.ink2)
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

                Text("提示：点左上角“添加字段”，再点击画布里的字段编辑属性")
                    .font(.footnote)
                    .foregroundStyle(EMTheme.ink2)
            }
            .padding(EMTheme.padding)
        }
    }

    private func summary(_ f: FormField) -> String {
        let type: String = switch f.type {
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
            _ = try await service.createForm(name: state.formName, schema: schema)
            state.errorMessage = nil
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
