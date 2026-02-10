//
//  FormBuilderCanvasView.swift
//  EstateMate
//

import SwiftUI
import UniformTypeIdentifiers

struct FormBuilderCanvasView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: FormBuilderState
    private let service = DynamicFormService()

    @State private var draggingField: FormField? = nil

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

                    VStack(spacing: 10) {
                        ForEach(state.fields) { f in
                            Button {
                                selectField(key: f.key)
                            } label: {
                                fieldRow(field: f)
                            }
                            .buttonStyle(.plain)
                            .onDrop(of: [.text], delegate: FieldDropDelegate(field: f, fields: $state.fields, dragging: $draggingField))
                        }
                    }
                    .padding(.top, 6)
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

                Text("提示：点右侧“＋”添加字段；点击字段编辑；长按右侧拖动把手调整顺序")
                    .font(.footnote)
                    .foregroundStyle(EMTheme.ink2)

                Spacer(minLength: 20)
            }
            .padding(EMTheme.padding)
        }
    }

    private func fieldRow(field f: FormField) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(f.label)
                        .font(.callout)
                        .foregroundStyle(EMTheme.ink)
                        .frame(width: 86, alignment: .leading)

                    Text(previewPlaceholder(for: f))
                        .font(.callout)
                        .foregroundStyle(EMTheme.ink2)

                    Spacer(minLength: 0)
                }

                Text(summary(f))
                    .font(.caption)
                    .foregroundStyle(EMTheme.ink2)
            }

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EMTheme.ink2)
                .padding(.leading, 6)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onDrag {
                    draggingField = f
                    return NSItemProvider(object: f.key as NSString)
                }
                .accessibilityLabel("拖动排序")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                .fill(EMTheme.paper2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                .stroke(state.selectedFieldKey == f.key ? EMTheme.accent.opacity(0.55) : EMTheme.line, lineWidth: 1)
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

    private struct FieldDropDelegate: DropDelegate {
        let field: FormField
        @Binding var fields: [FormField]
        @Binding var dragging: FormField?

        func dropEntered(info: DropInfo) {
            guard let dragging, dragging.key != field.key,
                  let fromIndex = fields.firstIndex(where: { $0.key == dragging.key }),
                  let toIndex = fields.firstIndex(where: { $0.key == field.key })
            else { return }

            withAnimation(.snappy) {
                fields.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }

        func performDrop(info: DropInfo) -> Bool {
            dragging = nil
            return true
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
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
