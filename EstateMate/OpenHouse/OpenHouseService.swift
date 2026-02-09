//
//  OpenHouseService.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import Foundation
import Supabase

@MainActor
final class OpenHouseService {
    private let client = SupabaseClientProvider.client

    func listEvents() async throws -> [OpenHouseEvent] {
        try await client
            .from("openhouse_events")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createEvent(title: String, isActive: Bool) async throws -> OpenHouseEvent {
        let payload = OpenHouseEventInsert(title: title, isActive: isActive)
        // PostgREST insert returns array when selecting
        return try await client
            .from("openhouse_events")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func setActive(eventId: UUID) async throws {
        // Set all events inactive, then activate selected. (Simple MVP approach)
        _ = try await client
            .from("openhouse_events")
            .update(["is_active": false])
            .neq("id", value: eventId.uuidString) // update others
            .execute()

        _ = try await client
            .from("openhouse_events")
            .update(["is_active": true])
            .eq("id", value: eventId.uuidString)
            .execute()
    }

    func getActiveEvent() async throws -> OpenHouseEvent? {
        let events: [OpenHouseEvent] = try await client
            .from("openhouse_events")
            .select()
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        return events.first
    }

    func createSubmission(_ submission: OpenHouseSubmissionInsert) async throws -> OpenHouseSubmission {
        try await client
            .from("openhouse_submissions")
            .insert(submission)
            .select()
            .single()
            .execute()
            .value
    }
}
