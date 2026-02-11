//
//  OpenHouseFormsView.swift
//  EstateMate
//

import SwiftUI

struct OpenHouseFormsView: View {
    private let service = DynamicFormService()

    @State private var forms: [FormRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var actionForm: FormRecord?
    @State private var showActions = false
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
                            NavigationLink {
                                FormBuilderAdaptiveView()
                            } label: {
                                HStack {
                                    Text("新建表单")
                                        .font(.headline)
                                    Spacer(minLength: 0)
                                    Image(systemName: "plus")
                                        .foregroundStyle(EMTheme.accent)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }

                        EMCard {
                            if forms.isEmpty {
                                Text("暂无表单")
                                    .foregroundStyle(EMTheme.ink2)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(forms.enumerated()), id: \.element.id) { idx, f in
                                        ZStack(alignment: .topTrailing) {
                                            NavigationLink {
                                                FormBuilderAdaptiveView(form: f)
                                            } label: {
                                                HStack(alignment: .top, spacing: 12) {
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        Text(f.name)
                                                            .font(.headline)
                                                            .foregroundStyle(EMTheme.ink)

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
                                                .padding(.trailing, 34) // reserve for the action button
                                            }
                                            .buttonStyle(.plain)

                                            Button {
                                                actionForm = f
                                                showActions = true
                                            } label: {
                                                Image(systemName: "ellipsis.circle")
                                                    .font(.title3)
                                                    .foregroundStyle(EMTheme.ink2)
                                                    .padding(.top, 10)
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.trailing, 2)
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
            .task { await load() }
            .refreshable { await load() }
            .confirmationDialog(
                "表单操作",
                isPresented: $showActions,
                titleVisibility: .visible,
                presenting: actionForm
            ) { f in
                Button("复制") {
                    Task { await copyForm(f) }
                }

                Button("删除", role: .destructive) {
                    Task { await deleteForm(f) }
                }

                Button("取消", role: .cancel) {}
            } message: { f in
                Text("\(f.name)")
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            forms = try await service.listForms()
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

    private func deleteForm(_ form: FormRecord) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.deleteForm(id: form.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
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
