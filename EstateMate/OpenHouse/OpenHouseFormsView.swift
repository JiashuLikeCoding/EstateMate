//
//  OpenHouseFormsView.swift
//  EstateMate
//

import SwiftUI

struct OpenHouseFormsView: View {
    private let service = DynamicFormService()

    private static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    /// Optional selection mode (used when this screen is shown as a “bind form” management sheet).
    /// When provided, we show a consistent “不绑定” row (same style as EmailTemplatesListView selection mode).
    var selection: Binding<UUID?>? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var forms: [FormSummary] = []
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
                                                FormBuilderLoadView(formId: f.id)
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

                                                        Text("点击进入编辑")
                                                            .font(.caption)
                                                            .foregroundStyle(EMTheme.ink2)

                                                        if let createdAt = f.createdAt {
                                                            Text("创建时间：\(OpenHouseFormsView.shortDateTime.string(from: createdAt))")
                                                                .font(.caption2)
                                                                .foregroundStyle(EMTheme.ink2)
                                                        }

                                                        if (f.isArchived ?? false), let archivedAt = f.archivedAt {
                                                            Text("归档时间：\(OpenHouseFormsView.shortDateTime.string(from: archivedAt))")
                                                                .font(.caption2)
                                                                .foregroundStyle(EMTheme.ink2)
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

                                                if (f.isArchived ?? false) == false {
                                                    Button("归档") {
                                                        Task { await archiveForm(f, isArchived: true) }
                                                    }
                                                }

                                                if includeArchived, (f.isArchived ?? false) {
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
            forms = try await service.listFormSummaries(includeArchived: includeArchived)
            errorMessage = nil
        } catch {
            // If archived forms include legacy/bad rows, the whole decode can fail.
            // In that case, still show non-archived forms and surface a friendly hint.
            if includeArchived {
                do {
                    forms = try await service.listFormSummaries(includeArchived: false)
                    errorMessage = "部分已归档表单数据异常，暂时无法读取。你可以先关闭“显示已归档”，或把有问题的归档表单复制/重新创建。"
                } catch {
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func copyForm(_ form: FormSummary) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            // Copy needs full schema; load it first.
            let full = try await service.getForm(id: form.id)
            _ = try await service.createForm(name: "\(full.name) 副本", schema: full.schema)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archiveForm(_ form: FormSummary, isArchived: Bool) async {
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

}
