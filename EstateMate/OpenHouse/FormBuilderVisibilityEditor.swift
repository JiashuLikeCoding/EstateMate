//
//  FormBuilderVisibilityEditor.swift
//  EstateMate
//

import SwiftUI

struct FormBuilderVisibilityEditor: View {
    @Binding var field: FormField
    let allFields: [FormField]

    @State private var showTriggerPicker: Bool = false

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { field.visibleWhen != nil },
            set: { on in
                if on {
                    // Seed with a best-effort default.
                    let candidate = availableTriggerFields.first
                    let key = candidate?.key ?? ""
                    let value = defaultValue(forTrigger: candidate)
                    field.visibleWhen = .init(dependsOnKey: key, op: .equals, value: value, clearOnHide: true)
                } else {
                    field.visibleWhen = nil
                }
            }
        )
    }

    private var availableTriggerFields: [FormField] {
        // Trigger fields must be real inputs.
        // Note: We allow using any non-decoration non-splice field as a trigger,
        // but the value picker will only support checkbox/select/dropdown in v1.
        allFields.filter { f in
            if f.key == field.key { return false }
            switch f.type {
            case .sectionTitle, .sectionSubtitle, .divider, .splice:
                return false
            default:
                return true
            }
        }
    }

    private func title(for f: FormField) -> String {
        let t = f.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? f.key : t
    }

    private func typeTitle(for f: FormField) -> String {
        switch f.type {
        case .checkbox: return "勾选"
        case .select: return "单选"
        case .dropdown: return "下拉"
        case .multiSelect: return "多选"
        case .text: return "文本"
        case .multilineText: return "多行文本"
        case .name: return "姓名"
        case .phone: return "手机号"
        case .email: return "邮箱"
        case .date: return "日期"
        case .time: return "时间"
        case .address: return "地址"
        case .sectionTitle: return "大标题"
        case .sectionSubtitle: return "小标题"
        case .divider: return "分割线"
        case .splice: return "拼接"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("显示条件")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)
                Spacer()
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                    .tint(EMTheme.accent)
            }

            if isEnabled.wrappedValue {
                if availableTriggerFields.isEmpty {
                    Text("暂无可用的条件字段（请先添加一个‘勾选/单选/下拉’字段）")
                        .font(.footnote)
                        .foregroundStyle(EMTheme.ink2)
                } else {
                    // dependsOn
                    let dependsOnKey = Binding<String>(
                        get: { field.visibleWhen?.dependsOnKey ?? "" },
                        set: { newKey in
                            guard var r = field.visibleWhen else { return }
                            r.dependsOnKey = newKey
                            // reset value to a sensible default for the selected trigger
                            let trigger = availableTriggerFields.first(where: { $0.key == newKey })
                            r.value = defaultValue(forTrigger: trigger)
                            field.visibleWhen = r
                        }
                    )

                    let op = Binding<FormVisibilityRule.Op>(
                        get: { field.visibleWhen?.op ?? .equals },
                        set: { newOp in
                            guard var r = field.visibleWhen else { return }
                            r.op = newOp
                            field.visibleWhen = r
                        }
                    )

                    let value = Binding<String>(
                        get: { field.visibleWhen?.value ?? "" },
                        set: { newValue in
                            guard var r = field.visibleWhen else { return }
                            r.value = newValue
                            field.visibleWhen = r
                        }
                    )

                    let clearOnHide = Binding<Bool>(
                        get: { field.visibleWhen?.clearOnHide ?? true },
                        set: { newValue in
                            guard var r = field.visibleWhen else { return }
                            r.clearOnHide = newValue
                            field.visibleWhen = r
                        }
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("当满足以下条件时显示")
                            .font(.footnote)
                            .foregroundStyle(EMTheme.ink2)

                        triggerRow(dependsOnKey: dependsOnKey)

                        Picker("条件", selection: op) {
                            ForEach(FormVisibilityRule.Op.allCases, id: \.self) { o in
                                Text(o.title).tag(o)
                            }
                        }
                        .pickerStyle(.segmented)

                        valuePicker(dependsOnKey: dependsOnKey.wrappedValue, value: value)

                        Toggle("隐藏时清空内容", isOn: clearOnHide)
                            .tint(EMTheme.accent)

                        Text("提示：适合做‘是否需要填写更多信息’这种联动。")
                            .font(.footnote)
                            .foregroundStyle(EMTheme.ink2)
                    }
                }
            }
        }
        .sheet(isPresented: $showTriggerPicker) {
            TriggerPickerSheet(
                title: "选择条件字段",
                fields: availableTriggerFields,
                selection: Binding(
                    get: {
                        let current = field.visibleWhen?.dependsOnKey ?? ""
                        return current.isEmpty ? (availableTriggerFields.first?.key ?? "") : current
                    },
                    set: { newKey in
                        // reuse setter logic for dependsOnKey
                        var r = field.visibleWhen
                        if r == nil {
                            r = .init(dependsOnKey: newKey, op: .equals, value: "", clearOnHide: true)
                        }
                        field.visibleWhen = r
                        // push through Binding setter to update default value
                        DispatchQueue.main.async {
                            // Apply via the dependsOnKey binding pathway by directly updating visibleWhen
                            guard var rr = field.visibleWhen else { return }
                            rr.dependsOnKey = newKey
                            let trigger = availableTriggerFields.first(where: { $0.key == newKey })
                            rr.value = defaultValue(forTrigger: trigger)
                            field.visibleWhen = rr
                        }
                    }
                ),
                subtitle: { f in
                    "\(typeTitle(for: f)) · \(f.key)"
                },
                titleFor: { f in
                    title(for: f)
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func triggerRow(dependsOnKey: Binding<String>) -> some View {
        let selected = availableTriggerFields.first(where: { $0.key == dependsOnKey.wrappedValue }) ?? availableTriggerFields.first
        let display = selected.map { "\(title(for: $0))" } ?? "选择字段"

        return Button {
            hideKeyboard()
            showTriggerPicker = true
        } label: {
            HStack(spacing: 10) {
                Text("条件字段")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)

                Spacer(minLength: 0)

                Text(display)
                    .font(.callout)
                    .foregroundStyle(EMTheme.ink)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EMTheme.ink2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .fill(EMTheme.paper2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .stroke(EMTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            // Ensure we always have a valid dependsOnKey when enabled.
            if dependsOnKey.wrappedValue.isEmpty, let first = availableTriggerFields.first {
                dependsOnKey.wrappedValue = first.key
            }
        }
    }

    @ViewBuilder
    private func valuePicker(dependsOnKey: String, value: Binding<String>) -> some View {
        let trigger = availableTriggerFields.first(where: { $0.key == dependsOnKey })

        switch trigger?.type {
        case .checkbox:
            Picker("值", selection: value) {
                Text("是").tag("是")
                Text("否").tag("否")
            }
            .pickerStyle(.segmented)

        case .select, .dropdown:
            let opts = trigger?.options ?? []
            if opts.isEmpty {
                Text("该字段没有选项，无法作为条件")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("触发值")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EMTheme.ink2)

                    FlowLayout(maxPerRow: 3, spacing: 8) {
                        ForEach(opts, id: \.self) { opt in
                            Button {
                                value.wrappedValue = opt
                            } label: {
                                EMChip(text: opt, isOn: value.wrappedValue == opt)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                            .fill(EMTheme.paper2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                            .stroke(EMTheme.line, lineWidth: 1)
                    )
                }
            }

        default:
            Text("目前仅支持用：勾选 / 单选 / 下拉 作为条件字段")
                .font(.footnote)
                .foregroundStyle(EMTheme.ink2)
        }
    }

    private func defaultValue(forTrigger trigger: FormField?) -> String {
        switch trigger?.type {
        case .checkbox:
            return "是"
        case .select, .dropdown:
            return trigger?.options?.first ?? ""
        default:
            return ""
        }
    }
}

private struct TriggerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let fields: [FormField]
    var selection: Binding<String>
    var subtitle: (FormField) -> String
    var titleFor: (FormField) -> String

    var body: some View {
        NavigationStack {
            List {
                ForEach(fields, id: \.key) { f in
                    Button {
                        selection.wrappedValue = f.key
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(titleFor(f))
                                    .font(.callout)
                                    .foregroundStyle(EMTheme.ink)
                                Text(subtitle(f))
                                    .font(.footnote)
                                    .foregroundStyle(EMTheme.ink2)
                            }

                            Spacer(minLength: 0)

                            if selection.wrappedValue == f.key {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(EMTheme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
