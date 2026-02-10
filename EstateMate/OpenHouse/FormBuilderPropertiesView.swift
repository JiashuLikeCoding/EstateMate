//
//  FormBuilderPropertiesView.swift
//  EstateMate
//

import SwiftUI

struct FormBuilderPropertiesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: FormBuilderState

    /// Called when user finishes an action (Cancel/Delete/etc.) in a context that wants to keep the sheet open.
    var onDone: (() -> Void)? = nil

    /// Called after a draft is successfully committed (Add/Update). Useful to auto-close the palette sheet.
    var onCommitDraft: (() -> Void)? = nil

    /// When provided (iPhone sheet), deleting a field should close the sheet instead of returning to the palette.
    var onDeleteClose: (() -> Void)? = nil

    private func typeTitle(_ type: FormFieldType) -> String {
        switch type {
        case .name: return "姓名"
        case .text: return "文本"
        case .multilineText: return "多行文本"
        case .phone: return "手机号"
        case .email: return "邮箱"
        case .select: return "单选"
        case .dropdown: return "下拉选框"
        case .multiSelect: return "多选"
        case .checkbox: return "勾选"
        case .sectionTitle: return "大标题"
        case .sectionSubtitle: return "小标题"
        case .divider: return "分割线"
        case .splice: return "拼接"
        }
    }

    private func typeIcon(_ type: FormFieldType) -> String {
        switch type {
        case .name: return "person"
        case .text: return "textformat"
        case .multilineText: return "text.alignleft"
        case .phone: return "phone"
        case .email: return "envelope"
        case .select: return "list.bullet"
        case .dropdown: return "chevron.down.square"
        case .multiSelect: return "checklist"
        case .checkbox: return "checkmark.square"
        case .sectionTitle: return "textformat.size.larger"
        case .sectionSubtitle: return "textformat.size.smaller"
        case .divider: return "line.horizontal.3"
        case .splice: return "rectangle.split.2x1"
        }
    }

    private func nameHint(_ format: NameFormat) -> String {
        switch format {
        case .firstLast:
            return "提示：将显示 2 个输入框（名、姓）"
        case .fullName:
            return "提示：将显示 1 个输入框（全名）"
        case .firstMiddleLast:
            return "提示：将显示 3 个输入框（名、中间名、姓）"
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
            get: {
                state.draftField ?? FormField(
                    key: "tmp",
                    label: "字段",
                    type: .text,
                    required: false,
                    options: nil,
                    selectStyle: nil,
                    textCase: TextCase.none,
                    nameFormat: nil,
                    nameKeys: nil,
                    phoneFormat: nil,
                    phoneKeys: nil
                )
            },
            set: { state.draftField = $0 }
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Color.clear.frame(height: 6)

                    HStack(spacing: 8) {
                        Image(systemName: typeIcon(binding.wrappedValue.type))
                            .foregroundStyle(EMTheme.accent)
                        Text(typeTitle(binding.wrappedValue.type))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(EMTheme.ink)
                    }

                    Text("设置完成后选择“添加”或“取消”")
                        .font(.footnote)
                        .foregroundStyle(EMTheme.ink2)
                }

                fieldCard(binding: binding)

                if state.editingFieldKey != nil {
                    // Updating an existing field (type change, etc.)
                    Button {
                        // Validate options
                        if (binding.wrappedValue.type == .select || binding.wrappedValue.type == .dropdown || binding.wrappedValue.type == .multiSelect), (binding.wrappedValue.options ?? []).isEmpty {
                            state.errorMessage = "该字段需要至少一个选项"
                            return
                        }
                        let hadDraft = (state.draftField != nil)
                        state.confirmDraft()
                        if hadDraft, state.draftField == nil {
                            onCommitDraft?()
                        }
                        if let onDone { onDone() } else { dismiss() }
                    } label: {
                        Text("更新字段")
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: false))

                    Button {
                        state.deleteSelectedIfPossible()
                        if let onDeleteClose {
                            onDeleteClose()
                        } else if let onDone {
                            onDone()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text("删除字段")
                    }
                    .buttonStyle(EMDangerButtonStyle())

                    Button {
                        state.cancelDraft()
                        if let onDeleteClose {
                            onDeleteClose()
                        } else if let onDone {
                            onDone()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text("取消")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())
                } else {
                    // Adding a new field
                    HStack(spacing: 12) {
                        Button {
                            state.cancelDraft()
                            if let onDone { onDone() } else { dismiss() }
                        } label: {
                            Text("取消")
                        }
                        .buttonStyle(EMSecondaryButtonStyle())

                        Button {
                            // Validate options
                            if (binding.wrappedValue.type == .select || binding.wrappedValue.type == .dropdown || binding.wrappedValue.type == .multiSelect), (binding.wrappedValue.options ?? []).isEmpty {
                                state.errorMessage = "该字段需要至少一个选项"
                                return
                            }
                            let hadDraft = (state.draftField != nil)
                            state.confirmDraft()
                            if hadDraft, state.draftField == nil {
                                onCommitDraft?()
                            }
                            if let onDone { onDone() } else { dismiss() }
                        } label: {
                            Text("添加")
                        }
                        .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                    }
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
                VStack(alignment: .leading, spacing: 6) {
                    Color.clear.frame(height: 6)

                    HStack(spacing: 8) {
                        Image(systemName: typeIcon(binding.wrappedValue.type))
                            .foregroundStyle(EMTheme.accent)
                        Text(typeTitle(binding.wrappedValue.type))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(EMTheme.ink)
                    }

                    Text("配置字段标题、必填与选项")
                        .font(.footnote)
                        .foregroundStyle(EMTheme.ink2)
                }

                fieldCard(binding: binding)

                Button {
                    state.deleteSelectedIfPossible()
                    if let onDeleteClose {
                        onDeleteClose()
                    } else if let onDone {
                        onDone()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("删除字段")
                }
                .buttonStyle(EMDangerButtonStyle())

                Button {
                    if let onDeleteClose {
                        onDeleteClose()
                    } else if let onDone {
                        onDone()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("取消")
                }
                .buttonStyle(EMSecondaryButtonStyle())

                Spacer(minLength: 20)
            }
            .padding(EMTheme.padding)
        }
    }

    private func fieldCard(binding: Binding<FormField>) -> some View {
        let isDecoration = binding.wrappedValue.type == .sectionTitle || binding.wrappedValue.type == .sectionSubtitle || binding.wrappedValue.type == .divider || binding.wrappedValue.type == .splice

        return EMCard {
            if binding.wrappedValue.type == .divider {
                Text("分割线")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(EMTheme.ink)

                // Divider has no title and is never required.
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        if binding.wrappedValue.required {
                            binding.wrappedValue.required = false
                        }
                        if binding.wrappedValue.dividerThickness == nil {
                            binding.wrappedValue.dividerThickness = 1
                        }
                        if binding.wrappedValue.dividerDashed == nil {
                            binding.wrappedValue.dividerDashed = false
                        }
                        // Ensure label stays empty.
                        if binding.wrappedValue.label.isEmpty == false {
                            binding.wrappedValue.label = ""
                        }
                    }

            } else if binding.wrappedValue.type == .splice {
                Text("拼接")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(EMTheme.ink)

                Text("提示：在大屏幕上将相邻字段拼到同一行，最多 4 个一行")
                    .font(.footnote)
                    .foregroundStyle(EMTheme.ink2)

                // Splice has no title and is never required.
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        if binding.wrappedValue.required {
                            binding.wrappedValue.required = false
                        }
                        if binding.wrappedValue.label.isEmpty == false {
                            binding.wrappedValue.label = ""
                        }
                    }

            } else if binding.wrappedValue.type == .sectionTitle {
                let c = EMTheme.decorationColor(for: binding.wrappedValue.decorationColorKey ?? EMTheme.DecorationColorKey.default.rawValue) ?? EMTheme.ink
                EMTextField(title: "大标题文字", text: binding.label, prompt: "例如：基本信息", textColor: c)

            } else if binding.wrappedValue.type == .sectionSubtitle {
                let c = EMTheme.decorationColor(for: binding.wrappedValue.decorationColorKey ?? EMTheme.DecorationColorKey.default.rawValue) ?? EMTheme.ink2
                EMTextField(title: "小标题文字", text: binding.label, prompt: "例如：请如实填写", textColor: c)

            } else {
                EMTextField(title: "字段标题", text: binding.label, prompt: "例如：姓名")
            }

            if isDecoration {
                // Decoration fields are never required.
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        if binding.wrappedValue.required {
                            binding.wrappedValue.required = false
                        }
                    }
            } else {
                Toggle("必填", isOn: binding.required)
                    .tint(EMTheme.accent)
            }

            // 类型已在顶部标题显示

            if binding.wrappedValue.type == .sectionTitle || binding.wrappedValue.type == .sectionSubtitle {
                Divider().overlay(EMTheme.line)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("字体大小")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(EMTheme.ink2)

                        Spacer()

                        Text("\(Int((binding.wrappedValue.fontSize ?? (binding.wrappedValue.type == .sectionTitle ? 22 : 16)).rounded())) pt")
                            .font(.caption)
                            .foregroundStyle(EMTheme.ink2)
                    }

                    Slider(
                        value: Binding(
                            get: { binding.wrappedValue.fontSize ?? (binding.wrappedValue.type == .sectionTitle ? 22 : 16) },
                            set: { binding.wrappedValue.fontSize = $0 }
                        ),
                        in: binding.wrappedValue.type == .sectionTitle ? 18...34 : 12...24,
                        step: 1
                    )
                }

                Divider().overlay(EMTheme.line)

                VStack(alignment: .leading, spacing: 10) {
                    Text("字体颜色")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EMTheme.ink2)

                    let colorKey = Binding<String>(
                        get: { binding.wrappedValue.decorationColorKey ?? EMTheme.DecorationColorKey.default.rawValue },
                        set: { newValue in
                            binding.wrappedValue.decorationColorKey = (newValue == EMTheme.DecorationColorKey.default.rawValue) ? nil : newValue
                        }
                    )

                    FlowLayout(maxPerRow: 3, spacing: 8) {
                        ForEach(EMTheme.decorationColorOptions, id: \.self) { key in
                            Button {
                                colorKey.wrappedValue = key
                            } label: {
                                EMChip(text: EMTheme.decorationColorTitle(for: key), isOn: colorKey.wrappedValue == key)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            // Switch to custom (initialize with accent if empty)
                            if (binding.wrappedValue.decorationColorKey ?? "").hasPrefix("#") == false {
                                binding.wrappedValue.decorationColorKey = EMTheme.hexFromColor(EMTheme.accent) ?? "#2F7A63"
                            }
                        } label: {
                            EMChip(text: "自定义", isOn: (binding.wrappedValue.decorationColorKey ?? "").hasPrefix("#"))
                        }
                        .buttonStyle(.plain)
                    }

                    if let key = binding.wrappedValue.decorationColorKey, key.hasPrefix("#") {
                        let pickerBinding = Binding<Color>(
                            get: { EMTheme.colorFromHex(key) ?? EMTheme.accent },
                            set: { newValue in
                                if let hex = EMTheme.hexFromColor(newValue) {
                                    binding.wrappedValue.decorationColorKey = hex
                                }
                            }
                        )

                        ColorPicker("", selection: pickerBinding, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
            }

            if binding.wrappedValue.type == .divider {
                Divider().overlay(EMTheme.line)

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("虚线", isOn: Binding(
                        get: { binding.wrappedValue.dividerDashed ?? false },
                        set: { binding.wrappedValue.dividerDashed = $0 }
                    ))
                    .tint(EMTheme.accent)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("粗度")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            Spacer()

                            Text("\(String(format: "%.0f", (binding.wrappedValue.dividerThickness ?? 1)))")
                                .font(.caption)
                                .foregroundStyle(EMTheme.ink2)
                        }

                        Slider(
                            value: Binding(
                                get: { binding.wrappedValue.dividerThickness ?? 1 },
                                set: { binding.wrappedValue.dividerThickness = $0 }
                            ),
                            in: 1...6,
                            step: 1
                        )
                    }

                    Divider().overlay(EMTheme.line)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("线条颜色")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(EMTheme.ink2)

                        let colorKey = Binding<String>(
                            get: { binding.wrappedValue.decorationColorKey ?? EMTheme.DecorationColorKey.default.rawValue },
                            set: { newValue in
                                binding.wrappedValue.decorationColorKey = (newValue == EMTheme.DecorationColorKey.default.rawValue) ? nil : newValue
                            }
                        )

                        FlowLayout(maxPerRow: 3, spacing: 8) {
                            ForEach(EMTheme.decorationColorOptions, id: \.self) { key in
                                Button {
                                    colorKey.wrappedValue = key
                                } label: {
                                    EMChip(text: EMTheme.decorationColorTitle(for: key), isOn: colorKey.wrappedValue == key)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                if (binding.wrappedValue.decorationColorKey ?? "").hasPrefix("#") == false {
                                    binding.wrappedValue.decorationColorKey = EMTheme.hexFromColor(EMTheme.accent) ?? "#2F7A63"
                                }
                            } label: {
                                EMChip(text: "自定义", isOn: (binding.wrappedValue.decorationColorKey ?? "").hasPrefix("#"))
                            }
                            .buttonStyle(.plain)
                        }

                        if let key = binding.wrappedValue.decorationColorKey, key.hasPrefix("#") {
                            let pickerBinding = Binding<Color>(
                                get: { EMTheme.colorFromHex(key) ?? EMTheme.accent },
                                set: { newValue in
                                    if let hex = EMTheme.hexFromColor(newValue) {
                                        binding.wrappedValue.decorationColorKey = hex
                                    }
                                }
                            )

                            ColorPicker("", selection: pickerBinding, supportsOpacity: false)
                                .labelsHidden()
                        }
                    }
                }
            }

            if binding.wrappedValue.type == .splice {
                // No extra options for splice.
                Divider().overlay(EMTheme.line).opacity(0)
            }

            if binding.wrappedValue.type == .checkbox {
                Divider().overlay(EMTheme.line)

                EMTextField(
                    title: "小标题（可选）",
                    text: Binding(
                        get: { binding.wrappedValue.subtitle ?? "" },
                        set: { binding.wrappedValue.subtitle = $0.nilIfBlank }
                    ),
                    prompt: "例如：点一下切换"
                )

            }

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

                }

                Text(nameHint(binding.wrappedValue.nameFormat ?? .firstLast))
                    .font(.footnote)
                    .foregroundStyle(EMTheme.ink2)
            }

            if binding.wrappedValue.type == .text {
                // 文本字段不再提供“全大写/全小写”格式选项（保持原样输入）。
                // 这里保留分割线占位，保持整体布局节奏一致。
                Divider().overlay(EMTheme.line).opacity(0)
            }

            if binding.wrappedValue.type == .phone {
                Divider().overlay(EMTheme.line)

                VStack(alignment: .leading, spacing: 10) {
                    Text("电话格式")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EMTheme.ink2)

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
                        Text("普通").tag(PhoneFormat.plain)
                        Text("带区号").tag(PhoneFormat.withCountryCode)
                    }
                    .pickerStyle(.segmented)
                }
            }

            if binding.wrappedValue.type == .select {
                Divider().overlay(EMTheme.line)

                VStack(alignment: .leading, spacing: 10) {
                    Text("样式")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EMTheme.ink2)

                    Picker("样式", selection: Binding(
                        get: { binding.wrappedValue.selectStyle ?? .dropdown },
                        set: { binding.wrappedValue.selectStyle = $0 }
                    )) {
                        Text("下拉").tag(SelectStyle.dropdown)
                        Text("圆点").tag(SelectStyle.dot)
                    }
                    .pickerStyle(.segmented)
                }

                Divider().overlay(EMTheme.line)

                FormBuilderOptionsEditor(options: Binding(
                    get: { binding.wrappedValue.options ?? [] },
                    set: { binding.wrappedValue.options = $0 }
                ))
            } else if binding.wrappedValue.type == .multiSelect {
                Divider().overlay(EMTheme.line)

                VStack(alignment: .leading, spacing: 10) {
                    Text("样式")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EMTheme.ink2)

                    Picker("样式", selection: Binding(
                        get: { binding.wrappedValue.multiSelectStyle ?? .chips },
                        set: { binding.wrappedValue.multiSelectStyle = $0 }
                    )) {
                        Text("Chips").tag(MultiSelectStyle.chips)
                        Text("列表").tag(MultiSelectStyle.checklist)
                        Text("下拉").tag(MultiSelectStyle.dropdown)
                    }
                    .pickerStyle(.segmented)
                }

                Divider().overlay(EMTheme.line)

                FormBuilderOptionsEditor(options: Binding(
                    get: { binding.wrappedValue.options ?? [] },
                    set: { binding.wrappedValue.options = $0 }
                ))
            } else if binding.wrappedValue.type == .dropdown {
                Divider().overlay(EMTheme.line)

                FormBuilderOptionsEditor(options: Binding(
                    get: { binding.wrappedValue.options ?? [] },
                    set: { binding.wrappedValue.options = $0 }
                ))
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

private struct FormBuilderOptionsEditor: View {
    @Binding var options: [String]

    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选项")
                .font(.footnote.weight(.medium))
                .foregroundStyle(EMTheme.ink2)

            VStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { idx in
                    HStack(spacing: 10) {
                        Text(options[idx])
                            .foregroundStyle(EMTheme.ink)
                        Spacer()
                        Button {
                            remove(at: idx)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(EMTheme.ink2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("删除选项")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                            .fill(EMTheme.paper2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                            .stroke(EMTheme.line, lineWidth: 1)
                    )
                }

                HStack(spacing: 10) {
                    TextField("新选项", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit { add() }

                    Button {
                        add()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(EMTheme.accent)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("添加选项")
                }
            }
        }
    }

    private func add() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.isEmpty == false else { return }
        if options.contains(t) { draft = ""; return }
        options.append(t)
        draft = ""
    }

    private func remove(at idx: Int) {
        guard options.indices.contains(idx) else { return }
        options.remove(at: idx)
    }
}
