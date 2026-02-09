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
                                    Spacer()
                                    Image(systemName: "plus")
                                        .foregroundStyle(EMTheme.accent)
                                }
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
                                        NavigationLink {
                                            OpenHouseFormDetailView(form: f)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(f.name)
                                                        .font(.headline)
                                                        .foregroundStyle(EMTheme.ink)
                                                    Text("字段数：\(f.schema.fields.count)")
                                                        .font(.caption)
                                                        .foregroundStyle(EMTheme.ink2)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundStyle(EMTheme.ink2)
                                            }
                                            .padding(.vertical, 10)
                                        }
                                        .buttonStyle(.plain)

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
        case .phone: return "手机号"
        case .email: return "邮箱"
        case .select: return "单选"
        }
    }
}
