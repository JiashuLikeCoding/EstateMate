//
//  DynamicFormService.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import Foundation
import Supabase

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

    // MARK: - Events

    func listEvents() async throws -> [OpenHouseEventV2] {
        try await client
            .from("openhouse_events")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createEvent(title: String, formId: UUID, isActive: Bool) async throws -> OpenHouseEventV2 {
        let payload = OpenHouseEventInsertV2(title: title, formId: formId, isActive: isActive)
        return try await client
            .from("openhouse_events")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
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

    func createSubmission(eventId: UUID, data: [String: String]) async throws -> SubmissionV2 {
        let payload = SubmissionInsertV2(eventId: eventId, data: data)
        return try await client
            .from("openhouse_submissions")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }
}
