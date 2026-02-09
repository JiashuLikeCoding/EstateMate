//
//  FormBuilderPropertiesView.swift
//  EstateMate
//

import SwiftUI

struct FormBuilderPropertiesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: FormBuilderState

    /// Called when user finishes an action (Add/Cancel/Delete) in a context that wants to keep the sheet open.
    var onDone: (() -> Void)? = nil

    private func typeTitle(_ type: FormFieldType) -> String {
        switch type {
        case .name: return "姓名"
        case .text: return "文本"
        case .phone: return "手机号"
        case .email: return "邮箱"
        case .select: return "单选"
        }
    }

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
            get: { state.draftField ?? FormField(key: "tmp", label: "字段", type: .text, required: false, options: nil, textCase: TextCase.none, nameFormat: nil, nameKeys: nil, phoneFormat: nil, phoneKeys: nil) },
            set: { state.draftField = $0 }
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                EMSectionHeader("新增字段", subtitle: "设置完成后选择“添加”或“取消”")

                fieldCard(binding: binding)

                HStack(spacing: 12) {
                    Button {
                        state.cancelDraft()
                        if let onDone { onDone() } else { dismiss() }
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
                        if let onDone { onDone() } else { dismiss() }
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
                    if let onDone { onDone() } else { dismiss() }
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

            // 类型由“字段库”决定，这里不提供切换，避免 UI 复杂。
            Text("类型：\(typeTitle(binding.wrappedValue.type))")
                .font(.footnote)
                .foregroundStyle(EMTheme.ink2)

            if binding.wrappedValue.type == .name {
                Divider().overlay(EMTheme.line)

                VStack(alignment: .leading, spacing: 10) {
                    Text("姓名格式")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EMTheme.ink2)

                    Picker("姓名格式", selection: Binding(
                        get: { binding.wrappedValue.nameFormat ?? .firstLast },
                        set: { newValue in
                            binding.wrappedValue.nameFormat = newValue
                            // Generate default keys if missing or mismatched count.
                            let base: [String]
                            switch newValue {
                            case .firstLast: base = ["first_name", "last_name"]
                            case .fullName: base = ["full_name"]
                            case .firstMiddleLast: base = ["first_name", "middle_name", "last_name"]
                            }
                            if (binding.wrappedValue.nameKeys ?? []).count != base.count {
                                binding.wrappedValue.nameKeys = base
                            }
                        }
                    )) {
                        Text("名+姓").tag(NameFormat.firstLast)
                        Text("全名").tag(NameFormat.fullName)
                        Text("带中间名").tag(NameFormat.firstMiddleLast)
                    }
                    .pickerStyle(.segmented)

                    Text("默认：名 + 姓")
                        .font(.footnote)
                        .foregroundStyle(EMTheme.ink2)
                }

                Text("提示：姓名字段会拆分为多个输入框，并分别存储。")
                    .font(.footnote)
                    .foregroundStyle(EMTheme.ink2)
            }

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

            if binding.wrappedValue.type == .phone {
                Divider().overlay(EMTheme.line)

                Picker("电话格式", selection: Binding(
                    get: { binding.wrappedValue.phoneFormat ?? .plain },
                    set: { newValue in
                        binding.wrappedValue.phoneFormat = newValue
                        let base: [String]
                        switch newValue {
                        case .plain: base = ["phone"]
                        case .withCountryCode: base = ["country_code", "phone_number"]
                        }
                        if (binding.wrappedValue.phoneKeys ?? []).count != base.count {
                            binding.wrappedValue.phoneKeys = base
                        }
                    }
                )) {
                    ForEach(PhoneFormat.allCases, id: \.self) { f in
                        Text(f.title).tag(f)
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
