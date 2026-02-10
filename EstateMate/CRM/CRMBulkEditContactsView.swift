//
//  CRMBulkEditContactsView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI

struct CRMBulkEditContactsView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedCount: Int
    let onApply: (_ patch: Patch) -> Void

    struct Patch {
        var stage: CRMContactStage?
        var source: CRMContactSource?
        var addTag: String
        var appendToNotes: String
    }

    @State private var stage: CRMContactStage? = nil
    @State private var source: CRMContactSource? = nil
    @State private var addTag: String = ""
    @State private var appendToNotes: String = ""

    @State private var showStagePicker = false
    @State private var showSourcePicker = false

    var body: some View {
        NavigationStack {
            EMScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        EMSectionHeader("批量修改", subtitle: "已选 \(selectedCount) 条客户。只会修改你填写的字段。")

                        EMCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("阶段")
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)

                                Button {
                                    showStagePicker = true
                                } label: {
                                    HStack {
                                        Text(stage?.displayName ?? "（不修改）")
                                            .foregroundStyle(stage == nil ? EMTheme.ink2 : EMTheme.ink)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .foregroundStyle(EMTheme.ink2)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }

                        EMCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("来源")
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)

                                Button {
                                    showSourcePicker = true
                                } label: {
                                    HStack {
                                        Text(source?.displayName ?? "（不修改）")
                                            .foregroundStyle(source == nil ? EMTheme.ink2 : EMTheme.ink)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .foregroundStyle(EMTheme.ink2)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }

                        EMCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("添加标签")
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)

                                TextField("例如：高意向 / 预算明确", text: $addTag)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }

                        EMCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("追加备注")
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)

                                TextField("例如：来自 2026-02-10 OpenHouse", text: $appendToNotes, axis: .vertical)
                                    .lineLimit(2...6)
                            }
                        }

                        Button {
                            hideKeyboard()
                            onApply(Patch(stage: stage, source: source, addTag: addTag, appendToNotes: appendToNotes))
                            dismiss()
                        } label: {
                            Text("应用到 \(selectedCount) 条")
                        }
                        .buttonStyle(EMPrimaryButtonStyle(disabled: selectedCount == 0))
                        .disabled(selectedCount == 0)

                        Button {
                            dismiss()
                        } label: {
                            Text("取消")
                        }
                        .buttonStyle(EMSecondaryButtonStyle())

                        Spacer(minLength: 20)
                    }
                    .padding(EMTheme.padding)
                }
            }
            .navigationTitle("批量修改")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showStagePicker) {
                CRMBulkStagePickerView(selected: $stage)
            }
            .sheet(isPresented: $showSourcePicker) {
                CRMBulkSourcePickerView(selected: $source)
            }
        }
        .onTapGesture { hideKeyboard() }
    }
}

private struct CRMBulkStagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: CRMContactStage?

    var body: some View {
        NavigationStack {
            EMScreen {
                List {
                    Button {
                        selected = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("（不修改）")
                            Spacer()
                            if selected == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(EMTheme.accent)
                            }
                        }
                    }

                    ForEach(CRMContactStage.allCases, id: \.self) { s in
                        Button {
                            selected = s
                            dismiss()
                        } label: {
                            HStack {
                                Text(s.displayName)
                                Spacer()
                                if selected == s {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(EMTheme.accent)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(EMTheme.paper)
            }
            .navigationTitle("选择阶段")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct CRMBulkSourcePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: CRMContactSource?

    var body: some View {
        NavigationStack {
            EMScreen {
                List {
                    Button {
                        selected = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("（不修改）")
                            Spacer()
                            if selected == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(EMTheme.accent)
                            }
                        }
                    }

                    ForEach(CRMContactSource.allCases, id: \.self) { s in
                        Button {
                            selected = s
                            dismiss()
                        } label: {
                            HStack {
                                Text(s.displayName)
                                Spacer()
                                if selected == s {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(EMTheme.accent)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(EMTheme.paper)
            }
            .navigationTitle("选择来源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
