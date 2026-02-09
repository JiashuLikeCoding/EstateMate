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
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(f.name)
                                        .font(.headline)
                                        .foregroundStyle(EMTheme.ink)

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
