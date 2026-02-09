//
//  FormPickerSheetView.swift
//  EstateMate
//

import SwiftUI

struct FormPickerSheetView: View {
    let forms: [FormRecord]
    @Binding var selectedFormId: UUID?

    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            List {
                if filteredForms.isEmpty {
                    Text(query.isEmpty ? "暂无表单" : "没有匹配的表单")
                        .foregroundStyle(EMTheme.ink2)
                } else {
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

                                    Text("字段数：\(f.schema.fields.count)")
                                        .font(.caption)
                                        .foregroundStyle(EMTheme.ink2)
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
                    Button("关闭") { dismiss() }
                        .foregroundStyle(EMTheme.ink2)
                }
            }
        }
    }

    private var filteredForms: [FormRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return forms }
        return forms.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private func fieldChips(for form: FormRecord) -> [String] {
        func typeTitle(_ type: FormFieldType) -> String {
            switch type {
            case .name: return "姓名"
            case .text: return "文本"
            case .phone: return "手机号"
            case .email: return "邮箱"
            case .select: return "单选"
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
