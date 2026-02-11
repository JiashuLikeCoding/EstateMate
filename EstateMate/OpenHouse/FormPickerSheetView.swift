//
//  FormPickerSheetView.swift
//  EstateMate
//

import SwiftUI

struct FormPickerSheetView: View {
    private let service = DynamicFormService()

    let forms: [FormRecord]
    @Binding var selectedFormId: UUID?

    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var localForms: [FormRecord]

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showCreateForm = false

    init(forms: [FormRecord], selectedFormId: Binding<UUID?>) {
        self.forms = forms
        self._selectedFormId = selectedFormId
        self._localForms = State(initialValue: forms)
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                if filteredForms.isEmpty {
                    Section {
                        Text(query.isEmpty ? "暂无表单" : "没有匹配的表单")
                            .foregroundStyle(EMTheme.ink2)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section {
                            NavigationLink {
                                OpenHouseFormsView()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "square.and.pencil")
                                        .foregroundStyle(EMTheme.accent)
                                    Text("去表单管理创建")
                                        .foregroundStyle(EMTheme.ink)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }

                            Button {
                                showCreateForm = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(EMTheme.accent)
                                    Text("直接新建表单")
                                        .foregroundStyle(EMTheme.ink)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Section {
                        Button {
                            selectedFormId = nil
                            dismiss()
                        } label: {
                            HStack {
                                Text("不绑定")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)
                                Spacer()
                                if selectedFormId == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(EMTheme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(filteredForms) { f in
                        Button {
                            selectedFormId = f.id
                            dismiss()
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

                                    EmptyView()
                                }
                                Spacer()

                                if selectedFormId == f.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(EMTheme.accent)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(EMTheme.ink2)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("选择表单")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索表单")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") { dismiss() }
                        .foregroundStyle(EMTheme.ink2)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建") {
                        showCreateForm = true
                    }
                    .foregroundStyle(EMTheme.accent)
                }
            }
            .sheet(isPresented: $showCreateForm, onDismiss: {
                Task { await reloadForms() }
            }) {
                NavigationStack {
                    FormBuilderAdaptiveView()
                }
            }
            .task {
                // Ensure we always show the latest forms (e.g. created on another screen).
                await reloadForms()
            }
        }
    }

    private var filteredForms: [FormRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return localForms }
        return localForms.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private func reloadForms() async {
        isLoading = true
        defer { isLoading = false }
        do {
            localForms = try await service.listForms()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fieldChips(for form: FormRecord) -> [String] {
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

        return form.schema.fields.map { f in
            let required = f.required ? "*" : ""
            return "\(f.label)\(required)（\(typeTitle(f.type))）"
        }
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

#Preview {
    NavigationStack {
        FormPickerSheetView(
            forms: [
                .init(id: UUID(), ownerId: nil, name: "到访登记", schema: .init(version: 1, fields: []), createdAt: Date()),
                .init(id: UUID(), ownerId: nil, name: "购房意向", schema: .init(version: 1, fields: []), createdAt: Date())
            ],
            selectedFormId: .constant(nil)
        )
    }
}
