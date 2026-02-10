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
                path: path,
                file: data,
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
        formId: UUID
    ) async throws -> OpenHouseEventV2 {
        // We don't overwrite is_active here; use setActive for that.
        let payload = OpenHouseEventUpdateV2(
            title: title,
            location: location,
            startsAt: startsAt,
            endsAt: endsAt,
            host: host,
            assistant: assistant,
            formId: formId
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

    func createSubmission(eventId: UUID, formId: UUID? = nil, data: [String: AnyJSON]) async throws -> SubmissionV2 {
        let payload = SubmissionInsertV2(eventId: eventId, formId: formId, data: data)
        return try await client
            .from("openhouse_submissions")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
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

