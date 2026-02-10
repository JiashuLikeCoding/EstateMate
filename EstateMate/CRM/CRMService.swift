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

        func mergedAddress(existing: String, incoming: String) -> String {
            let a = existing
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let b = incoming
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if a.isEmpty { return b.joined(separator: "\n") }
            if b.isEmpty { return a.joined(separator: "\n") }

            var seen = Set<String>()
            var out: [String] = []
            for item in (a + b) {
                let key = item.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                out.append(item)
            }
            return out.joined(separator: "\n")
        }

        func mergedNotes(existing: String, incoming: String) -> String {
            let e = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            let i = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
            if e.isEmpty { return i }
            if i.isEmpty { return e }
            if e.contains(i) { return e }
            return e + "\n\n" + i
        }

        func mergedTags(existing: [String]?, incoming: [String]?) -> [String]? {
            let a = existing ?? []
            let b = incoming ?? []
            if a.isEmpty && b.isEmpty { return nil }
            var seen = Set<String>()
            var out: [String] = []
            for t in (a + b) {
                let key = t.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { continue }
                if seen.contains(key.lowercased()) { continue }
                seen.insert(key.lowercased())
                out.append(key)
            }
            return out.isEmpty ? nil : out
        }

        if !email.isEmpty {
            if let existing = try await findContactByEmail(email) {
                return try await updateContact(
                    id: existing.id,
                    patch: CRMContactUpdate(
                        fullName: insert.fullName,
                        phone: phone.isEmpty ? nil : phone,
                        email: email,
                        notes: mergedNotes(existing: existing.notes, incoming: insert.notes),
                        address: mergedAddress(existing: existing.address, incoming: insert.address),
                        tags: mergedTags(existing: existing.tags, incoming: insert.tags),
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
                        notes: mergedNotes(existing: existing.notes, incoming: insert.notes),
                        address: mergedAddress(existing: existing.address, incoming: insert.address),
                        tags: mergedTags(existing: existing.tags, incoming: insert.tags),
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
                            notes: mergedNotes(existing: existing.notes, incoming: insert.notes),
                            address: mergedAddress(existing: existing.address, incoming: insert.address),
                            tags: mergedTags(existing: existing.tags, incoming: insert.tags),
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
                            notes: mergedNotes(existing: existing.notes, incoming: insert.notes),
                            address: mergedAddress(existing: existing.address, incoming: insert.address),
                            tags: mergedTags(existing: existing.tags, incoming: insert.tags),
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
        // Supabase/PostgREST errors can be wrapped; localizedDescription isn't always stable.
        // We check multiple surfaces and unwrap nested errors defensively.

        func messageHits(_ s: String) -> Bool {
            let m = s.lowercased()
            return m.contains("duplicate key value violates unique constraint")
                || m.contains("unique constraint")
                || m.contains("23505")
                || m.contains("duplicate key")
        }

        // Direct PostgREST error (preferred).
        if let e = error as? PostgrestError {
            if let code = e.code, code == "23505" { return true }
            if messageHits(e.message) { return true }
            if let detail = e.detail, messageHits(detail) { return true }
            if let hint = e.hint, messageHits(hint) { return true }
        }

        // Walk underlying errors.
        var cur: Error? = error
        var depth = 0
        while let err = cur, depth < 6 {
            if messageHits(err.localizedDescription) { return true }

            let ns = err as NSError
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
                cur = underlying
            } else {
                cur = nil
            }
            depth += 1
        }

        return false
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

    func listCustomFields(contactId: UUID, limit: Int = 200) async throws -> [CRMContactCustomField] {
        try await client
            .from("crm_contact_custom_fields")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .order("submitted_at", ascending: false)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func upsertCustomFields(_ items: [CRMContactCustomFieldUpsert]) async throws {
        guard !items.isEmpty else { return }

        _ = try await client
            .from("crm_contact_custom_fields")
            // The unique index is (contact_id, submission_id, field_key)
            .upsert(items, onConflict: "contact_id,submission_id,field_key")
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
