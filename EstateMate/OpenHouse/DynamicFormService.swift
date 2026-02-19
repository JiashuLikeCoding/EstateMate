//
//  DynamicFormService.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import Foundation
import Supabase
import UIKit

@MainActor
final class DynamicFormService {
    private let client = SupabaseClientProvider.client

    private struct EmptyResponse: Decodable {}


    // (conflict resolved)
    // MARK: - Forms

    func listForms(includeArchived: Bool = false) async throws -> [FormRecord] {
        do {
            var q = client
                .from("forms")
                .select()

            if includeArchived == false {
                q = q.eq("is_archived", value: false)
            }

            return try await q
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            // Backward compatibility if the column isn't migrated yet (or PostgREST schema cache is stale).
            let msg = (error as NSError).localizedDescription.lowercased()
            let isArchivedMissing = msg.contains("is_archived") && (
                msg.contains("does not exist") ||
                msg.contains("schema cache") ||
                msg.contains("could not find")
            )

            if isArchivedMissing {
                return try await client
                    .from("forms")
                    .select()
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }
            throw error
        }
    }

    func createForm(name: String, schema: FormSchema) async throws -> FormRecord {
        let payload = FormInsert(name: name, schema: schema)
        return try await client
            .from("forms")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func updateForm(id: UUID, name: String, schema: FormSchema) async throws -> FormRecord {
        let payload = FormInsert(name: name, schema: schema)
        return try await client
            .from("forms")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func archiveForm(id: UUID, isArchived: Bool) async throws {
        // Requires forms.is_archived column (see migration).
        let payload: [String: Bool] = ["is_archived": isArchived]
        _ = try await client
            .from("forms")
            .update(payload)
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Form Backgrounds (Storage)

    /// Upload a custom background image for a form. Returns the storage path.
    /// Note: requires you to create a Storage bucket named "openhouse_form_backgrounds".
    func uploadFormBackground(formId: UUID, image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.75) else {
            throw NSError(domain: "FormBackground", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法处理图片"])
        }

        let fileName = "\(UUID().uuidString).jpg"
        let path = "\(formId.uuidString)/\(fileName)"

        _ = try await client
            .storage
            .from("openhouse_form_backgrounds")
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        return path
    }

    /// Get a public URL for a stored background image.
    /// If the bucket is private, you may need signed URLs instead.
    func publicURLForFormBackground(path: String) -> URL? {
        try? client.storage
            .from("openhouse_form_backgrounds")
            .getPublicURL(path: path)
    }

    // MARK: - Events

    func listEvents(includeArchived: Bool = false) async throws -> [OpenHouseEventV2] {
        do {
            var q = client
                .from("openhouse_events")
                .select()

            if includeArchived == false {
                q = q.eq("is_archived", value: false)
            }

            return try await q
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            // Backward compatibility if the column isn't migrated yet.
            let msg = (error as NSError).localizedDescription.lowercased()
            if msg.contains("is_archived") && msg.contains("does not exist") {
                return try await client
                    .from("openhouse_events")
                    .select()
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }
            throw error
        }
    }

    func createEvent(
        title: String,
        location: String?,
        startsAt: Date?,
        endsAt: Date?,
        host: String?,
        assistant: String?,
        formId: UUID,
        emailTemplateId: UUID? = nil,
        isActive: Bool
    ) async throws -> OpenHouseEventV2 {
        let payload = OpenHouseEventInsertV2(
            title: title,
            location: location,
            startsAt: startsAt,
            endsAt: endsAt,
            host: host,
            assistant: assistant,
            formId: formId,
            emailTemplateId: emailTemplateId,
            isActive: isActive
        )
        return try await client
            .from("openhouse_events")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func updateEvent(
        id: UUID,
        title: String,
        location: String?,
        startsAt: Date?,
        endsAt: Date?,
        host: String?,
        assistant: String?,
        formId: UUID,
        emailTemplateId: UUID?
    ) async throws -> OpenHouseEventV2 {
        // We don't overwrite is_active here; use setActive for that.
        let payload = OpenHouseEventUpdateV2(
            title: title,
            location: location,
            startsAt: startsAt,
            endsAt: endsAt,
            host: host,
            assistant: assistant,
            formId: formId,
            emailTemplateId: emailTemplateId
        )
        return try await client
            .from("openhouse_events")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func archiveEvent(id: UUID, isArchived: Bool) async throws {
        // Requires openhouse_events.is_archived column (see migration).
        // Product rule: archiving an event also ends it.
        struct Patch: Encodable {
            var isArchived: Bool
            var isActive: Bool?
            var endedAt: Date?

            enum CodingKeys: String, CodingKey {
                case isArchived = "is_archived"
                case isActive = "is_active"
                case endedAt = "ended_at"
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(isArchived, forKey: .isArchived)

                if let isActive {
                    try container.encode(isActive, forKey: .isActive)
                }

                if let endedAt {
                    try container.encode(endedAt, forKey: .endedAt)
                }
            }
        }

        let payload: Patch
        if isArchived {
            payload = Patch(isArchived: true, isActive: false, endedAt: Date())
        } else {
            payload = Patch(isArchived: false, isActive: nil, endedAt: nil)
        }

        _ = try await client
            .from("openhouse_events")
            .update(payload)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteEvent(id: UUID) async throws {
        // Hard delete (kept for admin/debug only; UI uses archive).
        _ = try await client
            .from("openhouse_events")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func setActive(eventId: UUID) async throws {
        // Do not activate archived events; and do not touch archived ones when clearing actives.
        do {
            _ = try await client
                .from("openhouse_events")
                .update(["is_active": false])
                .eq("is_archived", value: false)
                .neq("id", value: eventId.uuidString)
                .execute()

            _ = try await client
                .from("openhouse_events")
                .update(["is_active": true])
                .eq("id", value: eventId.uuidString)
                .eq("is_archived", value: false)
                .execute()
        } catch {
            // Backward compatibility if the column isn't migrated yet.
            let msg = (error as NSError).localizedDescription.lowercased()
            if msg.contains("is_archived") && msg.contains("does not exist") {
                _ = try await client
                    .from("openhouse_events")
                    .update(["is_active": false])
                    .neq("id", value: eventId.uuidString)
                    .execute()

                _ = try await client
                    .from("openhouse_events")
                    .update(["is_active": true])
                    .eq("id", value: eventId.uuidString)
                    .execute()
                return
            }
            throw error
        }
    }

    func markEventEnded(eventId: UUID, endedAt: Date = Date()) async throws -> OpenHouseEventV2 {
        let payload = OpenHouseEventEndedAtPatch(endedAt: endedAt)
        return try await client
            .from("openhouse_events")
            .update(payload)
            .eq("id", value: eventId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func markEventOngoing(eventId: UUID) async throws -> OpenHouseEventV2 {
        let payload = OpenHouseEventEndedAtPatch(endedAt: nil)
        return try await client
            .from("openhouse_events")
            .update(payload)
            .eq("id", value: eventId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func getActiveEvent() async throws -> OpenHouseEventV2? {
        do {
            let events: [OpenHouseEventV2] = try await client
                .from("openhouse_events")
                .select()
                .eq("is_active", value: true)
                .eq("is_archived", value: false)
                .limit(1)
                .execute()
                .value
            return events.first
        } catch {
            // Backward compatibility if the column isn't migrated yet.
            let msg = (error as NSError).localizedDescription.lowercased()
            if msg.contains("is_archived") && msg.contains("does not exist") {
                let events: [OpenHouseEventV2] = try await client
                    .from("openhouse_events")
                    .select()
                    .eq("is_active", value: true)
                    .limit(1)
                    .execute()
                    .value
                return events.first
            }
            throw error
        }
    }

    func getForm(id: UUID) async throws -> FormRecord {
        try await client
            .from("forms")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    // MARK: - Submissions

    func createSubmission(
        eventId: UUID,
        formId: UUID? = nil,
        eventTitle: String? = nil,
        eventLocation: String? = nil,
        form: FormRecord? = nil,
        data: [String: AnyJSON]
    ) async throws -> SubmissionV2 {
        let payload = SubmissionInsertV2(eventId: eventId, formId: formId, data: data)
        let created: SubmissionV2 = try await client
            .from("openhouse_submissions")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        // Auto-add to CRM and send email (best effort; never block submission).
        Task { [weak self] in
            guard let self else { return }
            let contact = await self.bestEffortUpsertCRMContact(
                eventId: eventId,
                submissionId: created.id,
                submissionCreatedAt: created.createdAt,
                eventTitle: eventTitle,
                eventLocation: eventLocation,
                form: form,
                data: data
            )
            await self.bestEffortSendAutoEmailGmail(
                eventId: eventId,
                submissionId: created.id,
                eventTitle: eventTitle,
                form: form,
                data: data,
                fallbackEmail: contact?.email
            )
        }

        return created
    }

    func getEvent(id: UUID) async throws -> OpenHouseEventV2 {
        try await client
            .from("openhouse_events")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    private func buildCustomFieldUpserts(
        contactId: UUID,
        eventId: UUID,
        submissionId: UUID,
        eventTitle: String,
        eventLocation: String,
        submittedAt: Date?,
        form: FormRecord?,
        data: [String: AnyJSON]
    ) -> [CRMContactCustomFieldUpsert] {
        guard let fields = form?.schema.fields else {
            // No schema: store simple string values only.
            return data.compactMap { (k, v) in
                let value = (v.stringValue ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if value.isEmpty { return nil }
                return CRMContactCustomFieldUpsert(
                    contactId: contactId,
                    eventId: eventId,
                    submissionId: submissionId,
                    eventTitle: eventTitle,
                    eventLocation: eventLocation,
                    submittedAt: submittedAt,
                    fieldKey: k,
                    fieldLabel: k,
                    valueText: value
                )
            }
        }

        func valueString(for f: FormField) -> String {
            switch f.type {
            case .sectionTitle, .sectionSubtitle, .divider, .splice:
                return ""
            case .checkbox:
                let b = data[f.key]?.boolValue ?? false
                return b ? "是" : "否"
            case .multiSelect:
                let arr = (data[f.key]?.arrayValue ?? []).compactMap { $0.stringValue?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }.filter { !$0.isEmpty }
                return arr.joined(separator: "、")
            case .name:
                let keys = f.nameKeys ?? [f.key]
                let parts = keys.compactMap { data[$0]?.stringValue?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }.filter { !$0.isEmpty }
                return parts.joined(separator: " ")
            case .phone:
                var keys: [String] = []
                if let phoneKeys = f.phoneKeys { keys.append(contentsOf: phoneKeys) }
                keys.append(f.key)
                let parts = keys.compactMap { data[$0]?.stringValue?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }.filter { !$0.isEmpty }
                return parts.joined(separator: " ")
            case .date:
                // Stored as yyyy-MM-dd string
                return (data[f.key]?.stringValue ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            case .time:
                // Stored as HH:mm string
                return (data[f.key]?.stringValue ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            default:
                if let s = data[f.key]?.stringValue {
                    return s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                }
                // Fallback: best-effort stringify
                if let b = data[f.key]?.boolValue {
                    return b ? "是" : "否"
                }
                if let arr = data[f.key]?.arrayValue {
                    let joined = arr.compactMap { $0.stringValue }.filter { !$0.isEmpty }.joined(separator: ", ")
                    return joined
                }
                return ""
            }
        }

        var out: [CRMContactCustomFieldUpsert] = []
        out.reserveCapacity(fields.count)

        for f in fields {
            let value = valueString(for: f)
            if value.isEmpty { continue }
            out.append(
                CRMContactCustomFieldUpsert(
                    contactId: contactId,
                    eventId: eventId,
                    submissionId: submissionId,
                    eventTitle: eventTitle,
                    eventLocation: eventLocation,
                    submittedAt: submittedAt,
                    fieldKey: f.key,
                    fieldLabel: f.label,
                    valueText: value
                )
            )
        }

        return out
    }

    private func buildSubmissionNoteBlock(
        submissionId: UUID,
        eventTitle: String?,
        eventLocation: String?,
        form: FormRecord?,
        data: [String: AnyJSON]
    ) -> String {
        // CRM 备注：不自动写任何开放日/表单相关文字。
        // 表单内容请从 openhouse_submissions 原始 data 查看（联系人详情页里有入口）。
        return ""
    }

    private func bestEffortUpsertCRMContact(
        eventId: UUID,
        submissionId: UUID,
        submissionCreatedAt: Date?,
        eventTitle: String?,
        eventLocation: String?,
        form: FormRecord?,
        data: [String: AnyJSON]
    ) async -> CRMContact? {
        // If CRM is not set up yet, this will fail; we intentionally ignore the error.
        do {
            // Extract basics from schema.
            let extracted = extractCRMFields(form: form, data: data)
            if extracted.fullName.isEmpty && extracted.email.isEmpty && extracted.phone.isEmpty {
                return nil
            }

            let service = CRMService()

            // If title/location not passed (e.g. kiosk mode), fetch from DB.
            var resolvedEvent: OpenHouseEventV2?
            if eventTitle == nil && eventLocation == nil {
                resolvedEvent = try? await self.getEvent(id: eventId)
            } else {
                resolvedEvent = nil
            }

            let title = (eventTitle ?? resolvedEvent?.title)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let location = (eventLocation ?? resolvedEvent?.location)?.trimmingCharacters(in: .whitespacesAndNewlines)

            let contact = try await service.createOrMergeContact(
                CRMContactInsert(
                    fullName: extracted.fullName,
                    phone: extracted.phone,
                    email: extracted.email,
                    // CRM 备注：不自动写任何开放日/表单相关文字。
                    notes: "",
                    address: location ?? "",
                    tags: extracted.tags,
                    stage: .newLead,
                    source: .openHouse,
                    lastContactedAt: nil
                )
            )

            // Persist all non-decoration form fields into CRM structured storage (best effort).
            let custom = buildCustomFieldUpserts(
                contactId: contact.id,
                eventId: eventId,
                submissionId: submissionId,
                eventTitle: title ?? "",
                eventLocation: location ?? "",
                submittedAt: submissionCreatedAt,
                form: form,
                data: data
            )
            _ = try? await service.upsertCustomFields(custom)

            struct SubmissionContactPatch: Encodable {
                let contactId: UUID
                enum CodingKeys: String, CodingKey { case contactId = "contact_id" }
            }

            // Best-effort back-link: mark the submission with contact_id for faster future queries.
            _ = try? await client
                .from("openhouse_submissions")
                .update(SubmissionContactPatch(contactId: contact.id))
                .eq("id", value: submissionId.uuidString)
                .execute()

            return contact
        } catch {
            // no-op
            return nil
        }
    }

    private func extractCRMFields(form: FormRecord?, data: [String: AnyJSON]) -> (fullName: String, phone: String, email: String, notes: String, tags: [String]?) {
        guard let fields = form?.schema.fields else {
            // Without schema we can only do a very small heuristic.
            let email = (data["email"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let phone = (data["phone"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (data["full_name"]?.stringValue ?? data["name"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = (data["notes"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return (name, phone, email, notes, nil)
        }

        func firstString(forKeys keys: [String]) -> String {
            for k in keys {
                if let s = data[k]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                    return s
                }
            }
            return ""
        }

        func firstStringByLabel(_ matcher: (String) -> Bool, allowedTypes: [FormFieldType]) -> String {
            for f in fields {
                guard allowedTypes.contains(f.type) else { continue }
                let label = f.label.trimmingCharacters(in: .whitespacesAndNewlines)
                if matcher(label) {
                    let v = (data[f.key]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !v.isEmpty { return v }
                }
            }
            return ""
        }

        // Email
        let emailKey = fields.first(where: { $0.type == .email })?.key
        var email = (emailKey.map { firstString(forKeys: [$0]) } ?? "").lowercased()
        if email.isEmpty {
            // Fallback: common keys / labels when the field type is not set to .email.
            email = firstString(forKeys: ["email", "e_mail", "mail", "email_address"]).lowercased()
            if email.isEmpty {
                let labelMatch: (String) -> Bool = { l in
                    let lower = l.lowercased()
                    return lower.contains("email") || lower.contains("e-mail") || l.contains("邮箱") || l.contains("電子郵件")
                }
                email = firstStringByLabel(labelMatch, allowedTypes: [.text, .multilineText, .email]).lowercased()
            }
        }

        // Phone (also consider phoneKeys when withCountryCode)
        var phone = ""
        if let phoneField = fields.first(where: { $0.type == .phone }) {
            var keys: [String] = []
            if let phoneKeys = phoneField.phoneKeys { keys.append(contentsOf: phoneKeys) }
            keys.append(phoneField.key)
            phone = firstString(forKeys: keys)
        }
        if phone.isEmpty {
            phone = firstString(forKeys: ["phone", "mobile", "tel", "telephone", "cell"])
            if phone.isEmpty {
                let labelMatch: (String) -> Bool = { l in
                    let lower = l.lowercased()
                    return lower.contains("phone") || lower.contains("mobile") || lower.contains("tel")
                        || l.contains("电话") || l.contains("手機") || l.contains("手机") || l.contains("手机号") || l.contains("電話")
                }
                phone = firstStringByLabel(labelMatch, allowedTypes: [.text, .multilineText, .phone])
            }
        }

        // Name
        var fullName = ""
        if let nameField = fields.first(where: { $0.type == .name }) {
            let keys = nameField.nameKeys ?? [nameField.key]
            // Join parts if multiple.
            let parts = keys.compactMap { k in
                let v = (data[k]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return v.isEmpty ? nil : v
            }
            fullName = parts.joined(separator: " ")
        }
        if fullName.isEmpty {
            // Fallback: try to find a text field that looks like name.
            if let f = fields.first(where: { ($0.label.contains("姓名") || $0.label.lowercased().contains("name")) && ($0.type == .text || $0.type == .multilineText) }) {
                fullName = firstString(forKeys: [f.key])
            }
        }

        // Notes
        var notes = ""
        if let notesField = fields.first(where: { ($0.label.contains("备注") || $0.label.lowercased().contains("note")) && ($0.type == .text || $0.type == .multilineText) }) {
            notes = firstString(forKeys: [notesField.key])
        }

        // Tags: take first multiSelect labelled 标签
        var tags: [String]? = nil
        if let tagsField = fields.first(where: { $0.type == .multiSelect && ($0.label.contains("标签") || $0.label.lowercased().contains("tag")) }) {
            if let arr = data[tagsField.key]?.arrayValue {
                let t = arr.compactMap { $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                tags = t.isEmpty ? nil : t
            }
        }

        return (
            fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email.trimmingCharacters(in: .whitespacesAndNewlines),
            notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tags
        )
    }

    private func stripHTML(_ html: String) -> String {
        // Minimal HTML -> text for the plain-text part.
        // Keep it simple (we only need a readable fallback for Gmail).
        var s = html
        s = s.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)

        // Strip tags
        let pattern = "<[^>]+>"
        if let re = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            s = re.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
        }

        // Decode a few common entities
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&#39;", with: "'")

        // Normalize whitespace
        while s.contains("\n\n\n") { s = s.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func escapeHTML(_ s: String) -> String {
        var out = s
        out = out.replacingOccurrences(of: "&", with: "&amp;")
        out = out.replacingOccurrences(of: "<", with: "&lt;")
        out = out.replacingOccurrences(of: ">", with: "&gt;")
        out = out.replacingOccurrences(of: "\"", with: "&quot;")
        out = out.replacingOccurrences(of: "'", with: "&#39;")
        return out
    }

    private func plainTextToHTML(_ text: String) -> String {
        // Convert plain text into a stable HTML layout.
        // Key: remove single line breaks inside paragraphs (often introduced by copy/paste or transport)
        // so Gmail won't show "random" hard wraps.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Split on blank lines (paragraph separators)
        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let htmlParas = paragraphs.map { p -> String in
            // Heuristic:
            // - Regular paragraphs: collapse single newlines to spaces (prevents accidental hard-wrap artifacts).
            // - Signature / address blocks: keep line breaks (people often paste signatures with intentional \n).
            let lines = p.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            let nonEmptyLines = lines.filter { !$0.isEmpty }

            let looksLikeSignatureBlock: Bool = {
                // Many short lines, or multiple contact-like lines.
                if nonEmptyLines.count >= 3 {
                    let avgLen = nonEmptyLines.map { $0.count }.reduce(0, +) / max(nonEmptyLines.count, 1)
                    if avgLen <= 40 { return true }
                }
                let keyHints = ["cell:", "bus:", "wechat:", "email:", "website:"]
                let hit = nonEmptyLines.contains { line in
                    let lower = line.lowercased()
                    return keyHints.contains(where: { lower.contains($0) })
                }
                return hit
            }()

            if looksLikeSignatureBlock {
                let joined = nonEmptyLines.joined(separator: "\n")
                return "<pre style=\"margin:0 0 12px 0;white-space:pre-wrap;font-family:inherit;\">\(escapeHTML(joined))</pre>"
            } else {
                // Replace remaining single newlines with spaces to avoid hard-wrap artifacts.
                let oneLine = p.replacingOccurrences(of: "\n", with: " ")
                // Collapse multiple spaces.
                var collapsed = oneLine
                while collapsed.contains("  ") { collapsed = collapsed.replacingOccurrences(of: "  ", with: " ") }
                return "<p style=\"margin:0 0 12px 0;\">\(escapeHTML(collapsed))</p>"
            }
        }

        // Keep it minimal; Gmail will wrap naturally.
        return "<div style=\"font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;font-size:14px;line-height:1.6;color:#111;\">\n\(htmlParas.joined(separator: "\n"))\n</div>"
    }

    private func bestEffortSendAutoEmailGmail(
        eventId: UUID,
        submissionId: UUID,
        eventTitle: String?,
        form: FormRecord?,
        data: [String: AnyJSON],
        fallbackEmail: String? = nil
    ) async {
        do {
            // 1) If the submission doesn't have an email, we can't send.
            let extracted = extractCRMFields(form: form, data: data)
            var to = extracted.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if to.isEmpty, let fb = fallbackEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !fb.isEmpty {
                to = fb
            }
            if to.isEmpty {
                // If the contact already exists in CRM (e.g., user filled multiple forms),
                // fall back to their CRM email using the phone match.
                let phone = extracted.phone.trimmingCharacters(in: .whitespacesAndNewlines)
                if !phone.isEmpty, let contact = try? await CRMService().findExistingContact(email: "", phone: phone, excluding: nil) {
                    let existingEmail = contact.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !existingEmail.isEmpty {
                        to = existingEmail
                    }
                }
            }
            if to.isEmpty { return }

            // 2) Load event to see whether it is bound to an email template.
            struct EventEmailTemplate: Decodable {
                let id: UUID
                let title: String
                let location: String?
                let startsAt: Date?
                let emailTemplateId: UUID?

                enum CodingKeys: String, CodingKey {
                    case id
                    case title
                    case location
                    case startsAt = "starts_at"
                    case emailTemplateId = "email_template_id"
                }
            }

            let event: EventEmailTemplate = try await client
                .from("openhouse_events")
                .select("id,title,location,starts_at,email_template_id")
                .eq("id", value: eventId.uuidString)
                .single()
                .execute()
                .value

            // 2.1) If the event doesn't have a template bound, fall back to the latest OpenHouse template.
            var resolvedTemplateId = event.emailTemplateId
            if resolvedTemplateId == nil {
                resolvedTemplateId = try? await EmailTemplateService().listTemplates(workspace: .openhouse).first?.id
            }
            guard let templateId = resolvedTemplateId else { return }

            // 3) Load template (fallback if the bound id is stale/deleted).
            let template: EmailTemplateRecord
            do {
                template = try await EmailTemplateService().getTemplate(id: templateId)
            } catch {
                if let fallback = try? await EmailTemplateService().listTemplates(workspace: .openhouse).first {
                    template = fallback
                } else {
                    throw error
                }
            }

            // 4) Build variable overrides from submission data + event.
            var overrides: [String: String] = [:]

            let resolvedEventTitle = (eventTitle?.isEmpty == false ? eventTitle : event.title)
            overrides["event_title"] = resolvedEventTitle
            overrides["address"] = event.location ?? ""

            if let startsAt = event.startsAt {
                let df = DateFormatter()
                df.locale = .current
                df.timeZone = .current
                df.dateFormat = "yyyy-MM-dd"
                overrides["date"] = df.string(from: startsAt)

                let tf = DateFormatter()
                tf.locale = .current
                tf.timeZone = .current
                tf.dateFormat = "HH:mm"
                overrides["time"] = tf.string(from: startsAt)
            }

            overrides["client_email"] = to
            overrides["client_name"] = extracted.fullName

            // Name parts (prefer explicit keys, else derive from fullName when possible)
            let lastName = (data["last_name"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let firstName = (data["first_name"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let middleName = (data["middle_name"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if !firstName.isEmpty { overrides["firstname"] = firstName }
            if !lastName.isEmpty { overrides["lastname"] = lastName }
            if !middleName.isEmpty { overrides["middle_name"] = middleName }

            if overrides["firstname"] == nil || overrides["lastname"] == nil {
                let parts = extracted.fullName
                    .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
                    .map(String.init)
                    .filter { !$0.isEmpty }

                if parts.count >= 2 {
                    overrides["firstname"] = overrides["firstname"] ?? parts.first
                    overrides["lastname"] = overrides["lastname"] ?? parts.last
                    if parts.count > 2 {
                        let mid = parts.dropFirst().dropLast().joined(separator: " ")
                        if !mid.isEmpty {
                            overrides["middle_name"] = overrides["middle_name"] ?? mid
                        }
                    }
                }
            }

            for v in template.variables {
                let key = v.key
                if let val = data[key] {
                    if let s = val.stringValue, !s.isEmpty {
                        overrides[key] = s
                    } else if let arr = val.arrayValue {
                        let joined = arr.compactMap { $0.stringValue }.filter { !$0.isEmpty }.joined(separator: ", ")
                        if !joined.isEmpty {
                            overrides[key] = joined
                        }
                    }
                }
            }

            var subject = EmailTemplateRenderer.render(template.subject, variables: template.variables, overrides: overrides)
            if subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let fallback = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
                subject = fallback.isEmpty ? "Open House" : fallback
            }

            // Body can be either plain text or HTML.
            var bodyRaw = EmailTemplateRenderer.render(template.body, variables: template.variables, overrides: overrides)

            // Append unified footer (OpenHouse workspace only).
            if let settings = try? await EmailTemplateSettingsService().getSettings(workspace: .openhouse) {
                if !settings.footerHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    bodyRaw += "\n\n" + settings.footerHTML
                } else if !settings.footerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    bodyRaw += "\n\n" + settings.footerText
                }
            }

            let isHTML = bodyRaw.contains("<") && bodyRaw.contains(">")

            // If the user authored plain text, still send HTML too.
            // This prevents "random" hard wraps that can appear in some clients when the plain text contains
            // accidental line breaks (e.g. from copy/paste or transport). HTML will wrap naturally.
            let bodyHTML = isHTML ? bodyRaw : plainTextToHTML(bodyRaw)
            let bodyText = isHTML ? stripHTML(bodyRaw) : bodyRaw

            if subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }

            // 5) Invoke Edge Function (Gmail) with user's JWT.
            struct SendBody: Encodable {
                let to: String
                let subject: String
                let text: String
                let html: String?
                let submissionId: String
                let workspace: String
                let fromName: String?
            }

            let session = try await client.auth.session
            // For Edge Functions, include both Authorization (user JWT) and apikey (anon key).
            let headers = [
                "Authorization": "Bearer \(session.accessToken)",
                "apikey": SupabaseClientProvider.anonKey
            ]

            _ = try await client.functions.invoke(
                "gmail_send",
                options: .init(
                    headers: headers,
                    body: SendBody(
                        to: to,
                        subject: subject,
                        text: bodyText,
                        html: bodyHTML,
                        submissionId: submissionId.uuidString,
                        workspace: "openhouse",
                        fromName: template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : template.name
                    )
                )
            ) as EmptyResponse
        } catch {
            // best-effort: ignore, but keep a trace for debugging.
            print("[OpenHouseEmail] send failed: \(error)")
        }
    }

    func listSubmissions(eventId: UUID) async throws -> [SubmissionV2] {
        try await client
            .from("openhouse_submissions")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func listSubmissions(contactId: UUID) async throws -> [SubmissionV2] {
        try await client
            .from("openhouse_submissions")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // QR/public-web-form link removed.

    func updateSubmission(id: UUID, data: [String: AnyJSON], tags: [String]? = nil) async throws -> SubmissionV2 {
        let payload = SubmissionUpdateV2(data: data, tags: tags)
        return try await client
            .from("openhouse_submissions")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func updateSubmissionTags(id: UUID, tags: [String]) async throws -> SubmissionV2 {
        return try await client
            .from("openhouse_submissions")
            .update(["tags": tags])
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteSubmission(id: UUID) async throws {
        _ = try await client
            .from("openhouse_submissions")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Tags

    func listTags() async throws -> [OpenHouseTag] {
        try await client
            .from("openhouse_tags")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createTag(name: String) async throws -> OpenHouseTag {
        let payload = OpenHouseTagInsert(name: name)
        return try await client
            .from("openhouse_tags")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }
}
