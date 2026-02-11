//
//  OpenHouseFormsView.swift
//  EstateMate
//

import SwiftUI

struct OpenHouseFormsView: View {
    private let service = DynamicFormService()

    /// Optional selection mode (used when this screen is shown as a “bind form” management sheet).
    /// When provided, we show a consistent “不绑定” row (same style as EmailTemplatesListView selection mode).
    var selection: Binding<UUID?>? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var forms: [FormRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var includeArchived = false
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            EMScreen("表单管理") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        EMSectionHeader("表单管理", subtitle: "查看与管理你创建的表单")

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }

                        EMCard {
                            Toggle("显示已归档", isOn: $includeArchived)
                                .font(.callout)
                                .tint(EMTheme.accent)
                                .padding(.vertical, 10)
                        }

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }

                        if let selection {
                            EMCard {
                                Button {
                                    selection.wrappedValue = nil
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text("不绑定")
                                            .font(.headline)
                                            .foregroundStyle(EMTheme.ink)
                                        Spacer()
                                        if selection.wrappedValue == nil {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(EMTheme.accent)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        EMCard {
                            if forms.isEmpty {
                                VStack(alignment: .center, spacing: 12) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(EMTheme.ink2)

                                    Text("还没有任何表单")
                                        .font(.headline)
                                        .foregroundStyle(EMTheme.ink)

                                    Text("先创建一个表单，之后就可以在活动里直接绑定使用。")
                                        .font(.footnote)
                                        .foregroundStyle(EMTheme.ink2)
                                        .multilineTextAlignment(.center)

                                    NavigationLink {
                                        FormBuilderAdaptiveView()
                                    } label: {
                                        Text("新建第一个表单")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                                    .padding(.top, 4)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(forms.enumerated()), id: \.element.id) { idx, f in
                                        ZStack(alignment: .topTrailing) {
                                            NavigationLink {
                                                FormBuilderAdaptiveView(form: f)
                                            } label: {
                                                HStack(alignment: .top, spacing: 12) {
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                                                            Text(f.name)
                                                                .font(.headline)
                                                                .foregroundStyle(EMTheme.ink)

                                                            if (f.isArchived ?? false) {
                                                                EMChip(text: "已归档", isOn: true)
                                                            }
                                                        }

                                                        if f.schema.fields.isEmpty {
                                                            Text("暂无字段")
                                                                .font(.caption)
                                                                .foregroundStyle(EMTheme.ink2)
                                                        } else {
                                                            VStack(alignment: .leading, spacing: 6) {
                                                                ForEach(chunks(of: fieldChips(for: f), size: 3), id: \.self) { row in
                                                                    HStack(spacing: 8) {
                                                                        ForEach(row, id: \.self) { t in
                                                                            EMChip(text: t, isOn: false)
                                                                        }
                                                                        Spacer(minLength: 0)
                                                                    }
                                                                }
                                                            }
                                                            .padding(.vertical, 2)
                                                        }
                                                    }
                                                    Spacer(minLength: 0)
                                                }
                                                .contentShape(Rectangle())
                                                .padding(.vertical, 10)
                                                .padding(.trailing, 34) // reserve for menu
                                            }
                                            .buttonStyle(.plain)

                                            Menu {
                                                Button("复制") {
                                                    Task { await copyForm(f) }
                                                }

                                                Button("归档") {
                                                    Task { await archiveForm(f, isArchived: true) }
                                                }

                                                if includeArchived {
                                                    Button("取消归档") {
                                                        Task { await archiveForm(f, isArchived: false) }
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                                    .font(.title3.weight(.semibold))
                                                    .foregroundStyle(EMTheme.ink2)
                                                    .padding(10)
                                                    .background(
                                                        Circle().fill(EMTheme.paper2)
                                                    )
                                                    .overlay(
                                                        Circle().stroke(EMTheme.line, lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.top, 2)
                                            .padding(.trailing, 0)
                                        }

                                        if idx != forms.count - 1 {
                                            Divider().overlay(EMTheme.line)
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(EMTheme.padding)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FormBuilderAdaptiveView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .onChange(of: includeArchived) { _, _ in
                Task { await load() }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            forms = try await service.listForms(includeArchived: includeArchived)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyForm(_ form: FormRecord) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            _ = try await service.createForm(name: "\(form.name) 副本", schema: form.schema)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archiveForm(_ form: FormRecord, isArchived: Bool) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.archiveForm(id: form.id, isArchived: isArchived)
            await load()
        } catch {
            // Friendly hint when the column isn't migrated yet.
            let msg = error.localizedDescription
            if msg.lowercased().contains("is_archived") {
                errorMessage = "需要先执行一次数据库迁移：为 forms 增加 is_archived 字段（用于归档）"
            } else {
                errorMessage = msg
            }
        }
    }

    private func fieldChips(for form: FormRecord) -> [String] {
        // Keep it compact: show up to 6 chips, no count label.
        let maxCount = 6
        let fields = form.schema.fields

        func typeTitle(_ type: FormFieldType) -> String {
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
            case .date: return "日期"
            case .time: return "时间"
            case .address: return "地址"
            case .sectionTitle: return "大标题"
            case .sectionSubtitle: return "小标题"
            case .divider: return "分割线"
            case .splice: return "拼接"
            }
        }

        var chips: [String] = []
        for f in fields.prefix(maxCount) {
            let required = f.required ? "*" : ""
            chips.append("\(f.label)\(required)（\(typeTitle(f.type))）")
        }

        if fields.count > maxCount {
            chips.append("+\(fields.count - maxCount)")
        }

        return chips
    }

    private func chunks<T: Hashable>(of items: [T], size: Int) -> [[T]] {
        guard size > 0 else { return [items] }
        var result: [[T]] = []
        var i = 0
        while i < items.count {
            let end = min(items.count, i + size)
            result.append(Array(items[i..<end]))
            i = end
        }
        return result
    }
}

private struct OpenHouseFormDetailView: View {
    let form: FormRecord

    var body: some View {
        EMScreen("表单详情") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader(form.name, subtitle: "字段预览")

                    EMCard {
                        VStack(spacing: 0) {
                            ForEach(Array(form.schema.fields.enumerated()), id: \.element.id) { idx, f in
                                HStack {
                                    Text(f.label)
                                        .font(.headline)
                                    Spacer()
                                    Text(typeName(f))
                                        .font(.caption)
                                        .foregroundStyle(EMTheme.ink2)
                                }
                                .padding(.vertical, 10)

                                if idx != form.schema.fields.count - 1 {
                                    Divider().overlay(EMTheme.line)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
    }

    private func typeName(_ f: FormField) -> String {
        switch f.type {
        case .name: return "姓名"
        case .text: return "文本"
        case .multilineText: return "多行文本"
        case .phone: return "手机号"
        case .email: return "邮箱"
        case .select: return "单选"
        case .dropdown: return "下拉选框"
        case .multiSelect: return "多选"
        case .checkbox: return "勾选"
        case .date: return "日期"
        case .time: return "时间"
        case .address: return "地址"
        case .sectionTitle: return "大标题"
        case .sectionSubtitle: return "小标题"
        case .divider: return "分割线"
        case .splice: return "拼接"
        }
    }
}
