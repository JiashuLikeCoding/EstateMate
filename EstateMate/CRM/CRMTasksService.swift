//
//  CRMTasksService.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation
import Supabase

@MainActor
final class CRMTasksService {
    private let client = SupabaseClientProvider.client

    func listTasks(includeDone: Bool = false) async throws -> [CRMTask] {
        var q = client
            .from("crm_tasks")
            .select()

        if !includeDone {
            q = q.eq("is_done", value: false)
        }

        return try await q
            .order("due_at", ascending: true, nullsFirst: false)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func getTask(id: UUID) async throws -> CRMTask {
        try await client
            .from("crm_tasks")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func listTasks(contactId: UUID, includeDone: Bool = true) async throws -> [CRMTask] {
        var q = client
            .from("crm_tasks")
            .select()
            .eq("contact_id", value: contactId.uuidString)

        if !includeDone {
            q = q.eq("is_done", value: false)
        }

        return try await q
            .order("is_done", ascending: true)
            .order("due_at", ascending: true, nullsFirst: false)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func createTask(_ insert: CRMTaskInsert) async throws -> CRMTask {
        try await client
            .from("crm_tasks")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updateTask(id: UUID, patch: CRMTaskUpdate) async throws -> CRMTask {
        try await client
            .from("crm_tasks")
            .update(patch)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteTask(id: UUID) async throws {
        _ = try await client
            .from("crm_tasks")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
