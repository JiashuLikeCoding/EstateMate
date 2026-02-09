//
//  FormBuilderCanvasView.swift
//  EstateMate
//

import SwiftUI

struct FormBuilderCanvasView: View {
    @EnvironmentObject var state: FormBuilderState
    private let service = DynamicFormService()

    var body: some View {
        VStack(spacing: 0) {
            if let msg = state.errorMessage {
                Text(msg)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            List {
                Section("表单信息") {
                    TextField("表单名称", text: $state.formName)
                }

                Section("画布（可拖动排序）") {
                    if state.fields.isEmpty {
                        Text("从左侧字段库添加字段")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(state.fields) { f in
                        Button {
                            state.selectedFieldKey = f.key
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(f.label)
                                        .font(.headline)
                                    Text(summary(f))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if state.selectedFieldKey == f.key {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(red: 0.10, green: 0.78, blue: 0.66))
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onMove { from, to in
                        state.move(from: from, to: to)
                    }
                    .onDelete { idx in
                        state.fields.remove(atOffsets: idx)
                        if let sel = state.selectedFieldKey, !state.fields.contains(where: { $0.key == sel }) {
                            state.selectedFieldKey = nil
                        }
                    }
                }

                Section {
                    Button(state.isSaving ? "保存中..." : "保存表单") {
                        Task { await save() }
                    }
                    .disabled(state.isSaving || state.formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .toolbar { EditButton() }
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
