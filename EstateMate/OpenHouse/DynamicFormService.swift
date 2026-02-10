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

    // MARK: - Forms

    func listForms() async throws -> [FormRecord] {
        try await client
            .from("forms")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
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

    func listEvents() async throws -> [OpenHouseEventV2] {
        try await client
            .from("openhouse_events")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
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

    func deleteEvent(id: UUID) async throws {
        _ = try await client
            .from("openhouse_events")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func setActive(eventId: UUID) async throws {
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
        let events: [OpenHouseEventV2] = try await client
            .from("openhouse_events")
            .select()
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        return events.first
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

        // Auto-add to CRM (best effort; never block submission).
        Task { [weak self] in
            await self?.bestEffortUpsertCRMContact(
                eventId: eventId,
                submissionId: created.id,
                eventTitle: eventTitle,
                eventLocation: eventLocation,
                form: form,
                data: data
            )
        }

        // Auto-send email (best effort; never block submission).
        Task { [weak self] in
            await self?.bestEffortSendAutoEmailGmail(eventId: eventId, submissionId: created.id, eventTitle: eventTitle, form: form, data: data)
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

    private func buildSubmissionNoteBlock(
        submissionId: UUID,
        eventTitle: String?,
        eventLocation: String?,
        form: FormRecord?,
        data: [String: AnyJSON]
    ) -> String {
        let title = (eventTitle?.isEmpty == false) ? eventTitle! : "开放日"
        var lines: [String] = []
        lines.append("【开放日】\(title)")

        if let loc = eventLocation, !loc.isEmpty {
            lines.append("地址：\(loc)")
        }

        // Keep a tiny id so repeated submissions don't collapse into one.
        lines.append("记录ID：\(submissionId.uuidString.prefix(8))")

        if let fields = form?.schema.fields {
            for f in fields {
                // Decoration fields are display-only.
                if f.type == .sectionTitle || f.type == .sectionSubtitle || f.type == .divider || f.type == .splice {
                    continue
                }

                let value: String = {
                    switch f.type {
                    case .checkbox:
                        let b = data[f.key]?.boolValue ?? false
                        return b ? "是" : "否"
                    case .multiSelect:
                        let arr = (data[f.key]?.arrayValue ?? []).compactMap { $0.stringValue }.filter { !$0.isEmpty }
                        return arr.joined(separator: "、")
                    case .name:
                        let keys = f.nameKeys ?? [f.key]
                        let parts = keys.compactMap { data[$0]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        return parts.joined(separator: " ")
                    case .phone:
                        var keys: [String] = []
                        if let phoneKeys = f.phoneKeys { keys.append(contentsOf: phoneKeys) }
                        keys.append(f.key)
                        let parts = keys.compactMap { data[$0]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        return parts.joined(separator: " ")
                    default:
                        return (data[f.key]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }()

                if value.isEmpty { continue }
                lines.append("- \(f.label)：\(value)")
            }
        } else {
            // No schema: write a minimal payload.
            for (k, v) in data {
                if let s = v.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                    lines.append("- \(k)：\(s)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func bestEffortUpsertCRMContact(
        eventId: UUID,
        submissionId: UUID,
        eventTitle: String?,
        eventLocation: String?,
        form: FormRecord?,
        data: [String: AnyJSON]
    ) async {
        // If CRM is not set up yet, this will fail; we intentionally ignore the error.
        do {
            // Extract basics from schema.
            let extracted = extractCRMFields(form: form, data: data)
            if extracted.fullName.isEmpty && extracted.email.isEmpty && extracted.phone.isEmpty {
                return
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

            let noteBlock = buildSubmissionNoteBlock(
                submissionId: submissionId,
                eventTitle: title,
                eventLocation: location,
                form: form,
                data: data
            )

            let contact = try await service.createOrMergeContact(
                CRMContactInsert(
                    fullName: extracted.fullName,
                    phone: extracted.phone,
                    email: extracted.email,
                    notes: [noteBlock, extracted.notes].joined(separator: extracted.notes.isEmpty ? "" : "\n"),
                    address: location ?? "",
                    tags: extracted.tags,
                    stage: .newLead,
                    source: .openHouse,
                    lastContactedAt: nil
                )
            )

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
        } catch {
            // no-op
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

        // Email
        let emailKey = fields.first(where: { $0.type == .email })?.key
        let email = (emailKey.map { firstString(forKeys: [$0]) } ?? "").lowercased()

        // Phone (also consider phoneKeys when withCountryCode)
        var phone = ""
        if let phoneField = fields.first(where: { $0.type == .phone }) {
            var keys: [String] = []
            if let phoneKeys = phoneField.phoneKeys { keys.append(contentsOf: phoneKeys) }
            keys.append(phoneField.key)
            phone = firstString(forKeys: keys)
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

    private func bestEffortSendAutoEmailGmail(
        eventId: UUID,
        submissionId: UUID,
        eventTitle: String?,
        form: FormRecord?,
        data: [String: AnyJSON]
    ) async {
        do {
            // 1) If the submission doesn't have an email, we can't send.
            let extracted = extractCRMFields(form: form, data: data)
            let to = extracted.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if to.isEmpty { return }

            // 2) Load event to see whether it is bound to an email template.
            struct EventEmailTemplate: Decodable {
                let id: UUID
                let title: String
                let emailTemplateId: UUID?

                enum CodingKeys: String, CodingKey {
                    case id
                    case title
                    case emailTemplateId = "email_template_id"
                }
            }

            let event: EventEmailTemplate = try await client
                .from("openhouse_events")
                .select("id,title,email_template_id")
                .eq("id", value: eventId.uuidString)
                .single()
                .execute()
                .value

            guard let templateId = event.emailTemplateId else { return }

            // 3) Load template.
            let template = try await EmailTemplateService().getTemplate(id: templateId)

            // 4) Build variable overrides from submission data.
            var overrides: [String: String] = [:]
            overrides["event_title"] = (eventTitle?.isEmpty == false ? eventTitle : event.title)
            overrides["client_email"] = to
            overrides["client_name"] = extracted.fullName

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

            let subject = EmailTemplateRenderer.render(template.subject, variables: template.variables, overrides: overrides)
            let bodyText = EmailTemplateRenderer.render(template.body, variables: template.variables, overrides: overrides)

            if subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }

            // 5) Invoke Edge Function (Gmail) with user's JWT.
            struct SendBody: Encodable {
                let to: String
                let subject: String
                let text: String
                let submissionId: String
            }

            let session = try await client.auth.session
            let headers = ["Authorization": "Bearer \(session.accessToken)"]

            _ = try await client.functions.invoke(
                "gmail_send",
                options: .init(
                    headers: headers,
                    body: SendBody(
                        to: to,
                        subject: subject,
                        text: bodyText,
                        submissionId: submissionId.uuidString
                    )
                )
            ) as EmptyResponse
        } catch {
            // best-effort: ignore
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

