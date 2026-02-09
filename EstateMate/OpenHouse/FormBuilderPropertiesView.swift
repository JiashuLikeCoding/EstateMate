//
//  FormBuilderPropertiesView.swift
//  EstateMate
//

import SwiftUI

struct FormBuilderPropertiesView: View {
    @EnvironmentObject var state: FormBuilderState

    var body: some View {
        if let key = state.selectedFieldKey,
           let idx = state.fields.firstIndex(where: { $0.key == key }) {
            let binding = $state.fields[idx]

            Form {
                Section("字段") {
                    TextField("字段标题", text: binding.label)
                    Toggle("必填", isOn: binding.required)

                    Picker("类型", selection: binding.type) {
                        Text("文本").tag(FormFieldType.text)
                        Text("手机号").tag(FormFieldType.phone)
                        Text("邮箱").tag(FormFieldType.email)
                        Text("单选").tag(FormFieldType.select)
                    }
                }

                if state.fields[idx].type == .select {
                    Section("选项") {
                        TextField(
                            "用逗号分隔（例如：A,B,C）",
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
                    }
                }

                Section {
                    Button("删除字段", role: .destructive) {
                        state.selectedFieldKey = state.fields[idx].key
                        state.deleteSelectedIfPossible()
                    }
                }
            }
        } else {
            ContentUnavailableView("请选择一个字段", systemImage: "slider.horizontal.3")
        }
    }
}
