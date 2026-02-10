//
//  CRMService.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation
import Supabase

@MainActor
final class CRMService {
    private let client = SupabaseClientProvider.client

    func listContacts() async throws -> [CRMContact] {
        try await client
            .from("crm_contacts")
            .select()
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func getContact(id: UUID) async throws -> CRMContact {
        try await client
            .from("crm_contacts")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func createContact(_ insert: CRMContactInsert) async throws -> CRMContact {
        try await client
            .from("crm_contacts")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updateContact(id: UUID, patch: CRMContactUpdate) async throws -> CRMContact {
        try await client
            .from("crm_contacts")
            .update(patch)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteContact(id: UUID) async throws {
        _ = try await client
            .from("crm_contacts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
