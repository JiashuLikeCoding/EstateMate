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

                                Picker("阶段", selection: Binding(get: {
                                    stage ?? CRMContactStage.newLead
                                }, set: { newValue in
                                    stage = newValue
                                })) {
                                    Text("（不修改）").tag(CRMContactStage.newLead) // placeholder, see below
                                    ForEach(CRMContactStage.allCases, id: \.self) { s in
                                        Text(s.displayName).tag(s)
                                    }
                                }
                                .pickerStyle(.menu)

                                Button {
                                    stage = nil
                                } label: {
                                    Text("清除阶段（不修改）")
                                }
                                .buttonStyle(EMSecondaryButtonStyle())
                            }
                        }

                        EMCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("来源")
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)

                                Picker("来源", selection: Binding(get: {
                                    source ?? CRMContactSource.manual
                                }, set: { newValue in
                                    source = newValue
                                })) {
                                    Text("（不修改）").tag(CRMContactSource.manual) // placeholder, see below
                                    ForEach(CRMContactSource.allCases, id: \.self) { s in
                                        Text(s.displayName).tag(s)
                                    }
                                }
                                .pickerStyle(.menu)

                                Button {
                                    source = nil
                                } label: {
                                    Text("清除来源（不修改）")
                                }
                                .buttonStyle(EMSecondaryButtonStyle())
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
        }
        .onTapGesture { hideKeyboard() }
    }
}
