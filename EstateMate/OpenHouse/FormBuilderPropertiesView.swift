//
//  FormBuilderPropertiesView.swift
//  EstateMate
//

import SwiftUI

struct FormBuilderPropertiesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: FormBuilderState

    var body: some View {
        EMScreen {
            if state.draftField != nil {
                draftEditor
            } else if let key = state.selectedFieldKey,
                      let idx = state.fields.firstIndex(where: { $0.key == key }) {
                existingEditor(index: idx)
            } else {
                emptyState
            }
        }
    }

    private var draftEditor: some View {
        let binding = Binding<FormField>(
            get: { state.draftField ?? FormField(key: "tmp", label: "字段", type: .text, required: false, options: nil) },
            set: { state.draftField = $0 }
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                EMSectionHeader("新增字段", subtitle: "设置完成后选择“添加”或“取消”")

                fieldCard(binding: binding)

                HStack(spacing: 12) {
                    Button {
                        state.cancelDraft()
                        dismiss()
                    } label: {
                        Text("取消")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())

                    Button {
                        // Validate select options
                        if binding.wrappedValue.type == .select, (binding.wrappedValue.options ?? []).isEmpty {
                            state.errorMessage = "单选字段需要至少一个选项"
                            return
                        }
                        state.confirmDraft()
                        dismiss()
                    } label: {
                        Text("添加")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                }

                Spacer(minLength: 20)
            }
            .padding(EMTheme.padding)
        }
    }

    private func existingEditor(index idx: Int) -> some View {
        let binding = $state.fields[idx]

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                EMSectionHeader("属性", subtitle: "配置字段标题、必填与选项")

                fieldCard(binding: binding)

                Button {
                    state.deleteSelectedIfPossible()
                    dismiss()
                } label: {
                    Text("删除字段")
                }
                .buttonStyle(EMDangerButtonStyle())

                Spacer(minLength: 20)
            }
            .padding(EMTheme.padding)
        }
    }

    private func fieldCard(binding: Binding<FormField>) -> some View {
        EMCard {
            EMTextField(title: "字段标题", text: binding.label, prompt: "例如：姓名")

            Toggle("必填", isOn: binding.required)
                .tint(EMTheme.accent)

            Picker("类型", selection: binding.type) {
                Text("文本").tag(FormFieldType.text)
                Text("手机号").tag(FormFieldType.phone)
                Text("邮箱").tag(FormFieldType.email)
                Text("单选").tag(FormFieldType.select)
            }
            .pickerStyle(.menu)

            if binding.wrappedValue.type == .text {
                Divider().overlay(EMTheme.line)

                Picker("文本格式", selection: Binding(
                    get: { binding.wrappedValue.textCase ?? .none },
                    set: { binding.wrappedValue.textCase = $0 }
                )) {
                    ForEach(TextCase.allCases, id: \.self) { tc in
                        Text(tc.title).tag(tc)
                    }
                }
                .pickerStyle(.menu)
            }

            if binding.wrappedValue.type == .select {
                Divider().overlay(EMTheme.line)

                EMTextField(
                    title: "选项（用逗号分隔）",
                    text: Binding(
                        get: { (binding.wrappedValue.options ?? []).joined(separator: ",") },
                        set: { newValue in
                            let opts = newValue
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            binding.wrappedValue.options = opts
                        }
                    )
                )

                Text("例如：刚需,改善,投资")
                    .font(.footnote)
                    .foregroundStyle(EMTheme.ink2)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("请选择一个字段")
                .font(.headline)
            Text("在画布中点击字段即可编辑属性")
                .font(.footnote)
                .foregroundStyle(EMTheme.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(EMTheme.padding)
    }
}
