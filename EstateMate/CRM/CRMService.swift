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

    /// Create a new contact, or update an existing one if email/phone matches.
    /// Matching priority: email (if provided) -> phone (if provided) -> insert.
    func createOrMergeContact(_ insert: CRMContactInsert) async throws -> CRMContact {
        let email = insert.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let phone = insert.phone.trimmingCharacters(in: .whitespacesAndNewlines)

        if !email.isEmpty {
            if let existing = try await findContactByEmail(email) {
                return try await updateContact(
                    id: existing.id,
                    patch: CRMContactUpdate(
                        fullName: insert.fullName,
                        phone: phone.isEmpty ? nil : phone,
                        email: email,
                        notes: insert.notes,
                        tags: insert.tags,
                        stage: insert.stage,
                        source: insert.source,
                        lastContactedAt: insert.lastContactedAt
                    )
                )
            }
        }

        if !phone.isEmpty {
            if let existing = try await findContactByPhone(phone) {
                return try await updateContact(
                    id: existing.id,
                    patch: CRMContactUpdate(
                        fullName: insert.fullName,
                        phone: phone,
                        email: email.isEmpty ? nil : email,
                        notes: insert.notes,
                        tags: insert.tags,
                        stage: insert.stage,
                        source: insert.source,
                        lastContactedAt: insert.lastContactedAt
                    )
                )
            }
        }

        let normalized = CRMContactInsert(
            fullName: insert.fullName,
            phone: phone,
            email: email,
            notes: insert.notes,
            tags: insert.tags,
            stage: insert.stage,
            source: insert.source,
            lastContactedAt: insert.lastContactedAt
        )

        return try await client
            .from("crm_contacts")
            .insert(normalized)
            .select()
            .single()
            .execute()
            .value
    }

    private func findContactByEmail(_ email: String) async throws -> CRMContact? {
        let rows: [CRMContact] = try await client
            .from("crm_contacts")
            .select()
            .eq("email", value: email)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    private func findContactByPhone(_ phone: String) async throws -> CRMContact? {
        let rows: [CRMContact] = try await client
            .from("crm_contacts")
            .select()
            .eq("phone", value: phone)
            .limit(1)
            .execute()
            .value
        return rows.first
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

    /// Returns contact ids that participated in a given OpenHouse event.
    /// Uses openhouse_submissions.contact_id where event_id matches.
    func listContactIdsParticipated(eventId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable {
            let contactId: UUID?
            enum CodingKeys: String, CodingKey { case contactId = "contact_id" }
        }

        let rows: [Row] = try await client
            .from("openhouse_submissions")
            .select("contact_id")
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value

        return Set(rows.compactMap { $0.contactId })
    }
}
