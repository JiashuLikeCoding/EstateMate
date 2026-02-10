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
                        address: insert.address,
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
                        address: insert.address,
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
            address: insert.address,
            tags: insert.tags,
            stage: insert.stage,
            source: insert.source,
            lastContactedAt: insert.lastContactedAt
        )

        do {
            return try await client
                .from("crm_contacts")
                .insert(normalized)
                .select()
                .single()
                .execute()
                .value
        } catch {
            // Defensive: if we race with another insert (or data wasn't normalized),
            // fall back to find+update instead of surfacing a unique constraint error.
            if isUniqueConstraintViolation(error) {
                if !email.isEmpty, let existing = try await findContactByEmail(email) {
                    return try await updateContact(
                        id: existing.id,
                        patch: CRMContactUpdate(
                            fullName: insert.fullName,
                            phone: phone.isEmpty ? nil : phone,
                            email: email,
                            notes: insert.notes,
                            address: insert.address,
                            tags: insert.tags,
                            stage: insert.stage,
                            source: insert.source,
                            lastContactedAt: insert.lastContactedAt
                        )
                    )
                }
                if !phone.isEmpty, let existing = try await findContactByPhone(phone) {
                    return try await updateContact(
                        id: existing.id,
                        patch: CRMContactUpdate(
                            fullName: insert.fullName,
                            phone: phone,
                            email: email.isEmpty ? nil : email,
                            notes: insert.notes,
                            address: insert.address,
                            tags: insert.tags,
                            stage: insert.stage,
                            source: insert.source,
                            lastContactedAt: insert.lastContactedAt
                        )
                    )
                }
            }
            throw error
        }
    }

    func isUniqueConstraintViolation(_ error: Error) -> Bool {
        let msg = error.localizedDescription.lowercased()
        return msg.contains("duplicate key value violates unique constraint")
            || msg.contains("23505")
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

    /// Find an existing contact by email/phone (priority: email -> phone), excluding a specific id.
    /// Used for "unique constraint" conflict resolution when editing.
    func findExistingContact(email: String, phone: String, excluding excludedId: UUID?) async throws -> CRMContact? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalizedEmail.isEmpty, let c = try await findContactByEmail(normalizedEmail) {
            if excludedId == nil || c.id != excludedId { return c }
        }

        if !normalizedPhone.isEmpty, let c = try await findContactByPhone(normalizedPhone) {
            if excludedId == nil || c.id != excludedId { return c }
        }

        // Fallback: sometimes a conflict happens but direct eq query doesn't return (e.g. legacy formatting).
        // This is only used on error paths, so it's acceptable to scan.
        let all = try await listContacts()
        if !normalizedEmail.isEmpty {
            if let hit = all.first(where: { $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedEmail }) {
                if excludedId == nil || hit.id != excludedId { return hit }
            }
        }
        if !normalizedPhone.isEmpty {
            if let hit = all.first(where: { $0.phone.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedPhone }) {
                if excludedId == nil || hit.id != excludedId { return hit }
            }
        }

        return nil
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
