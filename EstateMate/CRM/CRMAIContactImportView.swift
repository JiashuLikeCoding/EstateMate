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
    @State private var previewRows: [PreviewRow] = []

    private let service = CRMAIContactImportService()

    struct PreviewRow: Identifiable {
        var id = UUID()
        var rowIndex: Int
        var title: String
        var subtitle: String?
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
                                previewRows = []
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

                    if !previewRows.isEmpty {
                        EMSectionHeader("预览", subtitle: "只展示前 20 行。导入时会处理全部。")

                        VStack(spacing: 10) {
                            ForEach(previewRows.prefix(20)) { r in
                                EMCard {
                                    HStack(alignment: .top, spacing: 10) {
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
                            }
                        }

                        Button {
                            Task { await apply() }
                        } label: {
                            Text(isApplying ? "导入中…" : "一键导入")
                        }
                        .buttonStyle(EMPrimaryButtonStyle(disabled: isApplying))
                        .disabled(isApplying)
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
        .onTapGesture { hideKeyboard() }
    }

    @State private var showFileImporter = false

    private func handlePickedFile(_ url: URL) async {
        errorMessage = nil
        summaryText = nil
        previewRows = []

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
            previewRows = res.results.map { r in
                let title = r.patch?.fullName?.nilIfBlank ?? r.patch?.email?.nilIfBlank ?? r.patch?.phone?.nilIfBlank ?? "（未命名）"
                let subtitle = [r.patch?.email?.nilIfBlank, r.patch?.phone?.nilIfBlank].compactMap { $0 }.joined(separator: " · ")
                return PreviewRow(rowIndex: r.rowIndex, title: title, subtitle: subtitle.isEmpty ? nil : subtitle, action: r.action, reason: r.reason)
            }
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
            let res = try await service.apply(fileName: pickedFileName, data: pickedFileData)
            summaryText = "导入完成：写入/更新 \(res.summary.upserted ?? 0) 行；跳过 \(res.summary.skipped) 行"
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
