//
//  CRMAIContactImportView.swift
//  EstateMate
//

import SwiftUI
import UniformTypeIdentifiers

struct CRMAIContactImportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pickedFileName: String?
    @State private var pickedFileData: Data?

    @State private var isAnalyzing = false
    @State private var isApplying = false
    @State private var errorMessage: String?

    @State private var summaryText: String?

    @State private var allPreviewRows: [PreviewRow] = []
    @State private var page: Int = 0
    private let pageSize = 20

    @State private var selectedRowIndices = Set<Int>()
    @State private var lastAppliedUpsertedCount: Int? = nil
    @State private var lastApplySkippedRows: [CRMAIContactImportService.ImportRow] = []
    @State private var showApplySkippedSheet = false

    @State private var showApplyDoneAlert = false
    @State private var applyDoneMessage: String = ""

    private let service = CRMAIContactImportService()

    struct PreviewRow: Identifiable {
        var id = UUID()
        var rowIndex: Int
        var title: String
        var subtitle: String?
        var notes: String?
        var action: String
        var reason: String?
    }

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("AI 智能导入客户", subtitle: "支持 CSV / XLSX。先解析预览，再一键导入。")

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "doc")
                                    .foregroundStyle(EMTheme.accent)
                                Text(pickedFileName ?? "未选择文件")
                                    .font(.callout)
                                    .foregroundStyle(pickedFileName == nil ? EMTheme.ink2 : EMTheme.ink)
                                    .lineLimit(1)
                                Spacer()
                            }

                            Button {
                                hideKeyboard()
                                errorMessage = nil
                                summaryText = nil
                                allPreviewRows = []
                                selectedRowIndices = []
                                page = 0
                                lastAppliedUpsertedCount = nil
                                lastApplySkippedRows = []
                                showApplySkippedSheet = false
                                showFileImporter = true
                            } label: {
                                Text("选择文件")
                            }
                            .buttonStyle(EMSecondaryButtonStyle())
                        }
                    }

                    if isAnalyzing {
                        EMCard {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("AI 正在解析并对号入座…")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    if let summaryText {
                        EMCard {
                            Text(summaryText)
                                .font(.subheadline)
                                .foregroundStyle(EMTheme.ink2)
                        }
                    }

                    if !allPreviewRows.isEmpty {
                        EMSectionHeader("预览", subtitle: "一次显示 20 行，可翻页。默认全选，可点选取消。")

                        let visibleRows = pageRows

                        VStack(spacing: 10) {
                            ForEach(visibleRows) { r in
                                EMCard {
                                    Button {
                                        guard r.action == "upsert" else { return }
                                        if selectedRowIndices.contains(r.rowIndex) {
                                            selectedRowIndices.remove(r.rowIndex)
                                        } else {
                                            selectedRowIndices.insert(r.rowIndex)
                                        }
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: r.action == "upsert"
                                                  ? (selectedRowIndices.contains(r.rowIndex) ? "checkmark.circle.fill" : "circle")
                                                  : "minus.circle")
                                                .foregroundStyle(r.action == "upsert"
                                                                 ? (selectedRowIndices.contains(r.rowIndex) ? EMTheme.accent : EMTheme.ink2)
                                                                 : EMTheme.ink2)
                                                .font(.system(size: 18, weight: .semibold))
                                                .padding(.top, 2)

                                            Text("#\(r.rowIndex)")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(EMTheme.ink2)
                                                .frame(width: 44, alignment: .leading)

                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(r.title)
                                                    .font(.headline)
                                                    .foregroundStyle(EMTheme.ink)
                                                    .lineLimit(1)

                                                if let subtitle = r.subtitle, !subtitle.isEmpty {
                                                    Text(subtitle)
                                                        .font(.caption)
                                                        .foregroundStyle(EMTheme.ink2)
                                                        .lineLimit(2)
                                                }

                                                if let notes = r.notes, !notes.isEmpty {
                                                    Text(notes)
                                                        .font(.caption2)
                                                        .foregroundStyle(EMTheme.ink2)
                                                        .lineLimit(3)
                                                }

                                                HStack(spacing: 8) {
                                                    Text(r.action == "upsert" ? "将写入/更新" : "跳过")
                                                        .font(.caption2.weight(.semibold))
                                                        .foregroundStyle(r.action == "upsert" ? EMTheme.accent : EMTheme.ink2)

                                                    if let reason = r.reason, !reason.isEmpty {
                                                        Text(reason)
                                                            .font(.caption2)
                                                            .foregroundStyle(EMTheme.ink2)
                                                            .lineLimit(2)
                                                    }
                                                }
                                            }

                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        EMCard {
                            HStack {
                                Button("上一页") {
                                    page = max(0, page - 1)
                                }
                                .disabled(page == 0)

                                Spacer()

                                Text("第 \(page + 1) / \(pageCount) 页")
                                    .font(.caption)
                                    .foregroundStyle(EMTheme.ink2)

                                Spacer()

                                Button("下一页") {
                                    page = min(pageCount - 1, page + 1)
                                }
                                .disabled(page >= pageCount - 1)
                            }
                        }

                        Button {
                            Task { await apply() }
                        } label: {
                            let selectedCount = selectedRowIndices.count
                            Text(isApplying ? "导入中…" : "一键导入（已选 \(selectedCount) 条）")
                        }
                        .buttonStyle(EMPrimaryButtonStyle(disabled: isApplying || selectedRowIndices.isEmpty))
                        .disabled(isApplying || selectedRowIndices.isEmpty)

                        if let lastAppliedUpsertedCount {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("本次已导入：\(lastAppliedUpsertedCount) 条")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)

                                if !lastApplySkippedRows.isEmpty {
                                    Button {
                                        showApplySkippedSheet = true
                                    } label: {
                                        Text("查看跳过原因（\(lastApplySkippedRows.count)）")
                                            .font(.caption)
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("关闭")
                    }
                    .buttonStyle(EMSecondaryButtonStyle())

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("AI 导入")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [
                .commaSeparatedText,
                UTType(filenameExtension: "xlsx") ?? .data,
                UTType(filenameExtension: "xls") ?? .data,
                .plainText,
                .data
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await handlePickedFile(url) }
            case .failure(let err):
                errorMessage = "选择文件失败：\(err.localizedDescription)"
            }
        }
        .sheet(isPresented: $showApplySkippedSheet) {
            NavigationStack {
                EMScreen {
                    List {
                        ForEach(lastApplySkippedRows, id: \.rowIndex) { r in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("#\(r.rowIndex)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(EMTheme.ink2)
                                Text(r.reason?.nilIfBlank ?? "跳过")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(EMTheme.paper)
                }
                .navigationTitle("跳过原因")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("关闭") { showApplySkippedSheet = false }
                    }
                }
            }
        }
        .alert("导入完成", isPresented: $showApplyDoneAlert) {
            Button("关闭导入") {
                dismiss()
            }
            Button("继续查看") {
                // keep screen
            }
        } message: {
            Text(applyDoneMessage)
        }
        .onTapGesture { hideKeyboard() }
    }

    @State private var showFileImporter = false

    private var pageCount: Int {
        max(1, Int(ceil(Double(allPreviewRows.count) / Double(pageSize))))
    }

    private var pageRows: [PreviewRow] {
        let start = page * pageSize
        if start >= allPreviewRows.count { return [] }
        let end = min(allPreviewRows.count, start + pageSize)
        return Array(allPreviewRows[start..<end])
    }

    private func handlePickedFile(_ url: URL) async {
        errorMessage = nil
        summaryText = nil
        allPreviewRows = []
        selectedRowIndices = []
        page = 0
        lastAppliedUpsertedCount = nil
        lastApplySkippedRows = []
        showApplySkippedSheet = false

        do {
            let ok = url.startAccessingSecurityScopedResource()
            defer {
                if ok { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            pickedFileName = url.lastPathComponent
            pickedFileData = data

            await analyze()
        } catch {
            errorMessage = "读取文件失败：\(error.localizedDescription)"
        }
    }

    private func analyze() async {
        guard let pickedFileName, let pickedFileData else {
            errorMessage = "请先选择文件"
            return
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let res = try await service.analyze(fileName: pickedFileName, data: pickedFileData)
            summaryText = "共 \(res.summary.total) 行；将写入/更新 \(res.summary.toUpsert ?? 0) 行；跳过 \(res.summary.skipped) 行"
            allPreviewRows = res.results.map { r in
                let title = r.patch?.fullName?.nilIfBlank ?? r.patch?.email?.nilIfBlank ?? r.patch?.phone?.nilIfBlank ?? "（未命名）"

                var subtitleBits: [String] = []
                let contactLine = [r.patch?.email?.nilIfBlank, r.patch?.phone?.nilIfBlank].compactMap { $0 }.joined(separator: " · ")
                if !contactLine.isEmpty { subtitleBits.append(contactLine) }
                if let st = r.sourceTime?.nilIfBlank { subtitleBits.append(st) }

                let subtitle = subtitleBits.joined(separator: "\n")
                let notes = r.patch?.notes?.nilIfBlank
                return PreviewRow(rowIndex: r.rowIndex, title: title, subtitle: subtitle.isEmpty ? nil : subtitle, notes: notes, action: r.action, reason: r.reason)
            }

            // 默认全选可写入的行
            selectedRowIndices = Set(res.results.filter { $0.action == "upsert" }.map { $0.rowIndex })
            page = 0
            lastAppliedUpsertedCount = nil
            lastApplySkippedRows = []
            showApplySkippedSheet = false
        } catch {
            errorMessage = "解析失败：\(error.localizedDescription)"
        }
    }

    private func apply() async {
        guard let pickedFileName, let pickedFileData else {
            errorMessage = "请先选择文件"
            return
        }

        isApplying = true
        defer { isApplying = false }

        do {
            let res = try await service.apply(
                fileName: pickedFileName,
                data: pickedFileData,
                selectedRowIndices: selectedRowIndices.sorted()
            )
            let upserted = res.summary.upserted ?? (res.upserted?.count ?? 0)
            lastAppliedUpsertedCount = upserted
            lastApplySkippedRows = res.skipped ?? []
            summaryText = "导入完成：写入/更新 \(upserted) 行；跳过 \(res.summary.skipped) 行"

            applyDoneMessage = summaryText ?? "导入完成"
            showApplyDoneAlert = true
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        CRMAIContactImportView()
    }
}
