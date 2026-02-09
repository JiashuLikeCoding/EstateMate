//
//  FormBuilderPropertiesView.swift
//  EstateMate
//

import SwiftUI

struct FormBuilderPropertiesView: View {
    @EnvironmentObject var state: FormBuilderState

    var body: some View {
        EMScreen {
            if let key = state.selectedFieldKey,
               let idx = state.fields.firstIndex(where: { $0.key == key }) {

                let binding = $state.fields[idx]

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        EMSectionHeader("属性", subtitle: "配置字段标题、必填与选项")

                        EMCard {
                            EMTextField(title: "字段标题", text: binding.label)

                            Toggle("必填", isOn: binding.required)
                                .tint(EMTheme.accent)

                            Picker("类型", selection: binding.type) {
                                Text("文本").tag(FormFieldType.text)
                                Text("手机号").tag(FormFieldType.phone)
                                Text("邮箱").tag(FormFieldType.email)
                                Text("单选").tag(FormFieldType.select)
                            }
                            .pickerStyle(.menu)
                        }

                        if state.fields[idx].type == .select {
                            EMCard {
                                Text("选项")
                                    .font(.headline)

                                EMTextField(
                                    title: "用逗号分隔",
                                    text: Binding(
                                        get: { (state.fields[idx].options ?? []).joined(separator: ",") },
                                        set: { newValue in
                                            let opts = newValue
                                                .split(separator: ",")
                                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                                .filter { !$0.isEmpty }
                                            state.fields[idx].options = opts
                                        }
                                    )
                                )

                                Text("例如：A,B,C")
                                    .font(.footnote)
                                    .foregroundStyle(EMTheme.ink2)
                            }
                        }

                        Button {
                            state.deleteSelectedIfPossible()
                        } label: {
                            Text("删除字段")
                        }
                        .buttonStyle(EMDangerButtonStyle())

                        Spacer(minLength: 20)
                    }
                    .padding(EMTheme.padding)
                }
            } else {
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
    }
}
