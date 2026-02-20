//
//  OpenHouseEventEditView.swift
//  EstateMate
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Supabase
import Storage

struct OpenHouseEventEditView: View {
    private let MAX_ATTACHMENT_BYTES = 6 * 1024 * 1024
    private let MAX_TOTAL_ATTACHMENT_BYTES = 8 * 1024 * 1024
    @Environment(\.dismiss) private var dismiss

    private let service = DynamicFormService()
    private let client = SupabaseClientProvider.client

    @State private var locationService = LocationAddressService()

    @State private var event: OpenHouseEventV2

    @State private var title: String
    @State private var location: String
    @State private var startsAt: Date
    @State private var hasTimeRange: Bool
    @State private var endsAt: Date
    @State private var host: String
    @State private var assistant: String

    @State private var forms: [FormRecord] = []
    @State private var selectedFormId: UUID?
    @State private var isFormSheetPresented: Bool = false
    @State private var isFormManagementPresented: Bool = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var templates: [EmailTemplateRecord] = []
    @State private var selectedEmailTemplateId: UUID?
    @State private var isEmailTemplateSheetPresented: Bool = false

    // Auto-reply attachments (bound to event, not email template)
    @State private var autoEmailAttachments: [EmailTemplateAttachment] = []
    @State private var isAttachmentPickerPresented: Bool = false
    @State private var isUploadingAttachment: Bool = false
    @State private var attachmentStatusMessage: String?
    @State private var attachmentStatusIsError: Bool = false

    @State private var showSaved = false

    @State private var showEndEarlyConfirm = false

    @State private var showArchiveConfirm = false

    @State private var isFillingLocation = false
    @State private var locationErrorMessage: String?
    @State private var showLocationError = false

    init(event: OpenHouseEventV2) {
        _event = State(initialValue: event)
        _title = State(initialValue: event.title)
        _location = State(initialValue: event.location ?? "")
        let start = event.startsAt ?? Date()
        _startsAt = State(initialValue: start)
        _hasTimeRange = State(initialValue: event.endsAt != nil)
        _endsAt = State(initialValue: event.endsAt ?? Calendar.current.date(byAdding: .hour, value: 2, to: start) ?? start)
        _host = State(initialValue: event.host ?? "")
        _assistant = State(initialValue: event.assistant ?? "")
        _selectedFormId = State(initialValue: event.formId)
        _selectedEmailTemplateId = State(initialValue: event.emailTemplateId)
        _autoEmailAttachments = State(initialValue: event.autoEmailAttachments ?? [])
    }

    var body: some View {
        EMScreen("编辑活动") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("编辑活动", subtitle: "修改标题、绑定表单、设置启用")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("活动标题")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            HStack(spacing: 10) {
                                TextField("例如：123 Main St - 2月10日", text: $title)
                                    .textInputAutocapitalization(.sentences)
                                    .autocorrectionDisabled(false)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                    .fill(EMTheme.paper2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                    .stroke(EMTheme.line, lineWidth: 1)
                            )
                        }

                        EMLocationField(
                            title: "活动地点",
                            text: $location,
                            prompt: "例如：123 Main St, Toronto",
                            isLoading: isFillingLocation,
                            onFillFromCurrentLocation: {
                                hideKeyboard()
                                Task { await fillLocationFromCurrent() }
                            }
                        )
                        .alert("无法获取当前位置", isPresented: $showLocationError) {
                            Button("好的", role: .cancel) {}
                        } message: {
                            Text(locationErrorMessage ?? "请稍后重试")
                        }

                        DatePicker("开始时间", selection: $startsAt)
                            .datePickerStyle(.compact)

                        Toggle("设置时间段", isOn: $hasTimeRange)

                        if hasTimeRange {
                            DatePicker("结束时间", selection: $endsAt)
                                .datePickerStyle(.compact)

                            if canEndEarly {
                                Button("提前结束活动") {
                                    showEndEarlyConfirm = true
                                }
                                .buttonStyle(EMDangerButtonStyle())
                                .alert("确认提前结束？", isPresented: $showEndEarlyConfirm) {
                                    Button("取消", role: .cancel) {}
                                    Button("结束活动", role: .destructive) {
                                        Task { await endEarly() }
                                    }
                                } message: {
                                    Text("将结束时间设置为当前时间，并把活动移动到“已结束”。")
                                }
                            }
                        }

                        EMTextField(title: "主理人", text: $host, prompt: "例如：嘉树")
                        EMTextField(title: "助手", text: $assistant, prompt: "例如：Jason")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("绑定表单")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            Button {
                                if forms.isEmpty {
                                    isFormManagementPresented = true
                                } else {
                                    isFormSheetPresented = true
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if selectedFormId == nil {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(EMTheme.accent)
                                        Text("绑定表单")
                                            .foregroundStyle(EMTheme.ink)
                                    } else {
                                        Text(selectedFormName)
                                            .foregroundStyle(EMTheme.ink)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .overlay(alignment: .bottom) {
                                Divider().overlay(EMTheme.line)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("绑定邮件模版")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            Button {
                                isEmailTemplateSheetPresented = true
                            } label: {
                                HStack(spacing: 10) {
                                    if selectedEmailTemplateId == nil {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(EMTheme.accent)
                                        Text("绑定邮件模版")
                                            .foregroundStyle(EMTheme.ink)
                                    } else {
                                        Text(selectedEmailTemplateName)
                                            .foregroundStyle(EMTheme.ink)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .overlay(alignment: .bottom) {
                                Divider().overlay(EMTheme.line)
                            }

                            Text("说明：用于本活动的默认邮件模版（后续可在客户/提交中一键套用）。")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
                                .padding(.top, -2)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("自动回复附件")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)

                                Spacer()

                                Button(isUploadingAttachment ? "上传中..." : "添加") {
                                    // Must bind an email template first.
                                    guard selectedEmailTemplateId != nil else {
                                        attachmentStatusIsError = true
                                        let limit = ByteCountFormatter.string(fromByteCount: Int64(MAX_ATTACHMENT_BYTES), countStyle: .file)
                                        attachmentStatusMessage = "添加失败：请先绑定邮件模版（附件不能超过\(limit)）"
                                        return
                                    }
                                    isAttachmentPickerPresented = true
                                }
                                .buttonStyle(EMSecondaryButtonStyle())
                                .disabled(isUploadingAttachment || selectedEmailTemplateId == nil)
                            }

                            if let attachmentStatusMessage {
                                Text(attachmentStatusMessage)
                                    .font(.footnote)
                                    .foregroundStyle(attachmentStatusIsError ? .red : EMTheme.ink2)
                            }

                            // Total size usage indicator
                            let usedBytes: Int = autoEmailAttachments.compactMap { $0.sizeBytes }.reduce(0, +)
                            let usedText = ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .file)
                            let totalBytes = MAX_TOTAL_ATTACHMENT_BYTES
                            let totalText = ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
                            let usageRatio = totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes)
                            let usageColor: Color = usageRatio >= 0.8 ? .orange : EMTheme.ink2

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text("附件总大小：\(usedText) / \(totalText)")
                                        .font(.footnote)
                                        .foregroundStyle(usageColor)

                                    Spacer()
                                }

                                ProgressView(value: Double(usedBytes), total: Double(totalBytes))
                                    .tint(usageRatio >= 0.8 ? .orange : EMTheme.accent)
                            }

                            let limitText = ByteCountFormatter.string(fromByteCount: Int64(MAX_ATTACHMENT_BYTES), countStyle: .file)
                            Text("说明：必须先绑定邮件模版；单个附件不能超过\(limitText)，总大小不能超过\(totalText)。")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)

                            if !autoEmailAttachments.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(autoEmailAttachments) { a in
                                        HStack(spacing: 10) {
                                            Image(systemName: "paperclip")
                                                .foregroundStyle(EMTheme.ink2)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(a.filename)
                                                    .font(.callout)
                                                    .foregroundStyle(EMTheme.ink)
                                                    .lineLimit(1)

                                                if let size = a.sizeBytes {
                                                    Text("\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))")
                                                        .font(.caption)
                                                        .foregroundStyle(EMTheme.ink2)
                                                }
                                            }

                                            Spacer()

                                            Button {
                                                Task { await removeAutoEmailAttachment(a) }
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        if a.id != autoEmailAttachments.last?.id {
                                            Divider().overlay(EMTheme.line)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                        .fill(EMTheme.paper2)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                        .stroke(EMTheme.line, lineWidth: 1)
                                )

                                Text("说明：这些附件会在访客提交本活动表单后，自动回复邮件里一起发送。")
                                    .font(.footnote)
                                    .foregroundStyle(EMTheme.ink2)
                            }
                        }

                        Button(isLoading ? "保存中..." : "保存修改") { 
                            Task { await save() }
                        }
                        .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading || !canSave))
                        .disabled(isLoading || !canSave)
                        .alert("已保存", isPresented: $showSaved) {
                            Button("好的") { dismiss() }
                        } message: {
                            Text("活动已更新")
                        }

                        Divider().overlay(EMTheme.line)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("活动状态")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)

                            HStack(spacing: 10) {
                                if event.endedAt != nil {
                                    Text("已结束")
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                } else {
                                    Text("进行中")
                                        .font(.footnote)
                                        .foregroundStyle(.green)
                                }

                                Spacer()

                                if event.isActive == false {
                                    Button("设为当前活动") {
                                        Task { await makeActive() }
                                    }
                                    .buttonStyle(EMSecondaryButtonStyle())
                                }
                            }

                            if shouldShowMarkOngoing {
                                Button("设为进行中") {
                                    Task { await markOngoing() }
                                }
                                .buttonStyle(EMSecondaryButtonStyle())
                            } else {
                                Button("设为已结束") {
                                    Task { await markEndedNow() }
                                }
                                .buttonStyle(EMDangerFilledButtonStyle(disabled: isLoading))
                                .disabled(isLoading)
                            }

                            Button(isArchived ? "取消归档" : "归档活动") {
                                showArchiveConfirm = true
                            }
                            .buttonStyle(EMPrimaryButtonStyle(disabled: isLoading))
                            .disabled(isLoading)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task { await load() }
        .sheet(isPresented: $isFormSheetPresented) {
            FormPickerSheetView(forms: forms, selectedFormId: $selectedFormId)
        }
        .sheet(isPresented: $isFormManagementPresented, onDismiss: {
            Task {
                await load()
                if selectedFormId == nil && forms.isEmpty == false {
                    isFormSheetPresented = true
                }
            }
        }) {
            NavigationStack {
                OpenHouseFormsView(selection: $selectedFormId)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("取消") { isFormManagementPresented = false }
                                .foregroundStyle(EMTheme.ink2)
                        }
                    }
            }
        }
        .sheet(isPresented: $isEmailTemplateSheetPresented) {
            NavigationStack {
                EmailTemplatesListView(workspace: .openhouse, selection: $selectedEmailTemplateId)
            }
        }
        .fileImporter(
            isPresented: $isAttachmentPickerPresented,
            allowedContentTypes: [.pdf, .data, .item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await handlePickedAutoEmailAttachments(urls) }
            case .failure(let error):
                attachmentStatusMessage = "选择文件失败：\(error.localizedDescription)"
            }
        }
        .alert(isArchived ? "取消归档这个活动？" : "归档这个活动？", isPresented: $showArchiveConfirm) {
            Button("取消", role: .cancel) {}
            Button(isArchived ? "取消归档" : "归档") {
                Task { await toggleArchive() }
            }
        } message: {
            Text(isArchived ? "取消归档后活动会重新出现在列表。" : "归档后活动会从列表隐藏，但提交记录会保留。")
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedFormId != nil
    }

    private var canEndEarly: Bool {
        // Only show when event has a time range and is not yet ended.
        hasTimeRange && endsAt > Date()
    }

    private var shouldShowMarkOngoing: Bool {
        // Only show ONE of: "设为进行中" vs "设为已结束"
        // Status is MANUAL only:
        // - ended_at != nil -> ended -> show "设为进行中"
        // - ended_at == nil -> ongoing -> show "设为已结束"
        event.endedAt != nil
    }

    private var selectedFormName: String {
        guard let selectedFormId else { return "请选择..." }
        return forms.first(where: { $0.id == selectedFormId })?.name ?? "请选择..."
    }

    private var selectedEmailTemplateName: String {
        guard let selectedEmailTemplateId else { return "请选择..." }
        let t = templates.first(where: { $0.id == selectedEmailTemplateId })
        let name = (t?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "（未命名模版）" : name
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            forms = try await service.listForms()
            templates = try await EmailTemplateService().listTemplates(workspace: nil)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fillLocationFromCurrent() async {
        isFillingLocation = true
        defer { isFillingLocation = false }
        do {
            let addr = try await locationService.fillCurrentAddress()
            if !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                location = addr
            }
        } catch {
            locationErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showLocationError = true
        }
    }

    private func fillTitleFromCurrentLocation() async {
        isFillingLocation = true
        defer { isFillingLocation = false }
        do {
            let addr = try await locationService.fillCurrentAddress()
            let trimmed = addr.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            title = suggestedTitle(from: trimmed, date: startsAt)
        } catch {
            locationErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showLocationError = true
        }
    }

    private func suggestedTitle(from address: String, date: Date) -> String {
        let street = address.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? address
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "M月d日"
        let dateText = df.string(from: date)
        let s = street.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? dateText : "\(s) - \(dateText)"
    }

    private func save() async {
        guard let formId = selectedFormId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await service.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                startsAt: startsAt,
                endsAt: hasTimeRange ? (endsAt < startsAt ? startsAt : endsAt) : nil,
                host: host.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                assistant: assistant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                formId: formId,
                emailTemplateId: selectedEmailTemplateId,
                autoEmailAttachments: autoEmailAttachments
            )
            // Keep manual state (isActive / endedAt) in sync too.
            event = updated
            errorMessage = nil
            showSaved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func endEarly() async {
        guard let formId = selectedFormId else { return }
        let now = Date()
        let end = max(startsAt, now)

        isLoading = true
        defer { isLoading = false }
        do {
            // 1) Update scheduled end time (planning info)
            _ = try await service.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                startsAt: startsAt,
                endsAt: end,
                host: host.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                assistant: assistant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                formId: formId,
                emailTemplateId: selectedEmailTemplateId,
                autoEmailAttachments: autoEmailAttachments
            )

            // 2) Mark manually ended
            let updated = try await service.markEventEnded(eventId: event.id, endedAt: now)
            event = updated

            endsAt = end
            hasTimeRange = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeActive() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.setActive(eventId: event.id)
            event.isActive = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markOngoing() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await service.markEventOngoing(eventId: event.id)
            event = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markEndedNow() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await service.markEventEnded(eventId: event.id, endedAt: Date())
            event = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var isArchived: Bool {
        event.isArchived ?? false
    }

    private func toggleArchive() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Toggle archive; keep submissions.
            // Product rule: archiving also ends the event.
            let next = !isArchived
            try await service.archiveEvent(id: event.id, isArchived: next)
            event.isArchived = next
            if next {
                event.isActive = false
                event.endedAt = Date()
            }
            errorMessage = nil

            // After toggling archive state, go back to list.
            // - Archiving: it disappears immediately from default list
            // - Unarchiving: user expectation is to return to list as well
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handlePickedAutoEmailAttachments(_ urls: [URL]) async {
        isUploadingAttachment = true
        attachmentStatusMessage = nil
        attachmentStatusIsError = false
        defer { isUploadingAttachment = false }

        var rejectedOversize: [String] = []
        var rejectedTotal: [String] = []
        var uploadedCount = 0

        var runningTotalBytes: Int = autoEmailAttachments.compactMap { $0.sizeBytes }.reduce(0, +)

        do {
            for url in urls {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                }

                let rawName = (url.lastPathComponent.isEmpty ? "附件" : url.lastPathComponent)
                let filenameDisplay = rawName.removingPercentEncoding ?? rawName

                let data: Data = try {
                    do {
                        return try Data(contentsOf: url)
                    } catch {
                        // Fallback: coordinate read (some providers require it).
                        let coordinator = NSFileCoordinator()
                        var readError: NSError?
                        var resultData: Data?
                        coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { readURL in
                            resultData = try? Data(contentsOf: readURL)
                        }
                        if let readError { throw readError }
                        if let resultData { return resultData }
                        throw error
                    }
                }()

                if data.count > MAX_ATTACHMENT_BYTES {
                    rejectedOversize.append(filenameDisplay)
                    continue
                }

                // Total size check (existing + newly added in this batch)
                if runningTotalBytes + data.count > MAX_TOTAL_ATTACHMENT_BYTES {
                    rejectedTotal.append(filenameDisplay)
                    continue
                }

                let ext = url.pathExtension

                let mimeType: String? = {
                    if let ut = UTType(filenameExtension: ext),
                       let preferred = ut.preferredMIMEType {
                        return preferred
                    }
                    if ext.lowercased() == "pdf" { return "application/pdf" }
                    return "application/octet-stream"
                }()

                let safeFilename: String = {
                    let cleaned = filenameDisplay
                        .replacingOccurrences(of: "/", with: "_")
                        .replacingOccurrences(of: "\\", with: "_")

                    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._- ")
                    let ascii = cleaned.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
                    let collapsed = String(ascii)
                        .replacingOccurrences(of: " ", with: "_")
                        .replacingOccurrences(of: "__", with: "_")

                    let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
                    return trimmed.isEmpty ? "attachment.pdf" : trimmed
                }()

                let path = "\(event.id.uuidString)/\(UUID().uuidString)_\(safeFilename)"

                _ = try await client.storage
                    .from("email_attachments")
                    .upload(path, data: data, options: FileOptions(contentType: mimeType, upsert: true))

                let item = EmailTemplateAttachment(
                    storagePath: path,
                    filename: filenameDisplay,
                    mimeType: mimeType,
                    sizeBytes: data.count
                )

                autoEmailAttachments.removeAll { $0.storagePath == item.storagePath }
                autoEmailAttachments.append(item)
                runningTotalBytes += data.count
                uploadedCount += 1
            }

            let limit = ByteCountFormatter.string(fromByteCount: Int64(MAX_ATTACHMENT_BYTES), countStyle: .file)
            let totalLimit = ByteCountFormatter.string(fromByteCount: Int64(MAX_TOTAL_ATTACHMENT_BYTES), countStyle: .file)

            if uploadedCount > 0 {
                await saveAutoEmailAttachmentsOnly()

                var problems: [String] = []
                if rejectedOversize.isEmpty == false {
                    problems.append("以下文件过大（不能超过\(limit)）：\(rejectedOversize.joined(separator: "、"))")
                }
                if rejectedTotal.isEmpty == false {
                    problems.append("以下文件导致总大小超限（总大小不能超过\(totalLimit)）：\(rejectedTotal.joined(separator: "、"))")
                }

                if problems.isEmpty == false {
                    attachmentStatusIsError = true
                    attachmentStatusMessage = "添加失败（已跳过）：" + problems.joined(separator: "；")
                }
            } else if rejectedOversize.isEmpty == false || rejectedTotal.isEmpty == false {
                // Nothing uploaded; keep the rejection message (do not overwrite with "附件已保存").
                attachmentStatusIsError = true
                if rejectedOversize.isEmpty == false {
                    attachmentStatusMessage = "添加失败：附件过大（不能超过\(limit)）：\(rejectedOversize.joined(separator: "、"))"
                } else {
                    attachmentStatusMessage = "添加失败：总大小超限（总大小不能超过\(totalLimit)）：\(rejectedTotal.joined(separator: "、"))"
                }
            }
        } catch {
            attachmentStatusIsError = true
            attachmentStatusMessage = "添加失败：\(error.localizedDescription)"
        }
    }

    private func removeAutoEmailAttachment(_ a: EmailTemplateAttachment) async {
        autoEmailAttachments.removeAll { $0.storagePath == a.storagePath }

        // Auto-save so the next submission email will reflect the change.
        await saveAutoEmailAttachmentsOnly()

        // Best-effort delete from Storage as well.
        do {
            try await client.storage
                .from("email_attachments")
                .remove(paths: [a.storagePath])
        } catch {
            // It's OK if we can't delete immediately.
            print("[AutoEmailAttachments] storage delete failed: \(error)")
        }
    }

    private func saveAutoEmailAttachmentsOnly() async {
        guard let formId = selectedFormId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let updated = try await service.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                startsAt: startsAt,
                endsAt: hasTimeRange ? (endsAt < startsAt ? startsAt : endsAt) : nil,
                host: host.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                assistant: assistant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                formId: formId,
                emailTemplateId: selectedEmailTemplateId,
                autoEmailAttachments: autoEmailAttachments
            )
            event = updated
            attachmentStatusIsError = false
            attachmentStatusMessage = "附件已保存"
        } catch {
            attachmentStatusIsError = true
            attachmentStatusMessage = "添加失败：\(error.localizedDescription)"
        }
    }
}

private struct EMLocationField: View {
    let title: String
    @Binding var text: String
    var prompt: String

    var isLoading: Bool
    var onFillFromCurrentLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(EMTheme.ink2)

            HStack(spacing: 10) {
                TextField(prompt, text: $text)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)

                Button {
                    onFillFromCurrentLocation()
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.callout.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(EMTheme.accent)
                .disabled(isLoading)
                .accessibilityLabel("使用当前位置")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .fill(EMTheme.paper2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .stroke(EMTheme.line, lineWidth: 1)
            )
        }
    }
}
