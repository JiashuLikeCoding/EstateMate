//
//  CRMEmailService.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation
import Supabase

@MainActor
final class CRMEmailService {
    private let client = SupabaseClientProvider.client

    func listLogs(contactId: UUID) async throws -> [CRMEmailLog] {
        try await client
            .from("crm_email_logs")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .order("sent_at", ascending: false, nullsFirst: false)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func createLog(_ insert: CRMEmailLogInsert) async throws -> CRMEmailLog {
        try await client
            .from("crm_email_logs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updateLog(id: UUID, patch: CRMEmailLogUpdate) async throws -> CRMEmailLog {
        try await client
            .from("crm_email_logs")
            .update(patch)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteLog(id: UUID) async throws {
        _ = try await client
            .from("crm_email_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
