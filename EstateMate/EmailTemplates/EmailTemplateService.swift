//
//  EmailTemplateService.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation
import Supabase

@MainActor
final class EmailTemplateService {
    private let client = SupabaseClientProvider.client

    func listTemplates(workspace: EstateMateWorkspaceKind, includeArchived: Bool = false) async throws -> [EmailTemplateRecord] {
        var q = client
            .from("email_templates")
            .select()
            .eq("workspace", value: workspace.rawValue)

        if !includeArchived {
            q = q.eq("is_archived", value: false)
        }

        return try await q
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func createTemplate(_ insert: EmailTemplateInsert) async throws -> EmailTemplateRecord {
        try await client
            .from("email_templates")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updateTemplate(id: UUID, patch: EmailTemplateUpdate) async throws -> EmailTemplateRecord {
        try await client
            .from("email_templates")
            .update(patch)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func archiveTemplate(id: UUID, isArchived: Bool = true) async throws -> EmailTemplateRecord {
        try await updateTemplate(id: id, patch: EmailTemplateUpdate(isArchived: isArchived))
    }
}
