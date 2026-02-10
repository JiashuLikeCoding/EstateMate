//
//  EmailTemplateSettingsService.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation
import Supabase

@MainActor
final class EmailTemplateSettingsService {
    private let client = SupabaseClientProvider.client

    func getSettings(workspace: EstateMateWorkspaceKind) async throws -> EmailTemplateSettingsRecord? {
        let rows: [EmailTemplateSettingsRecord] = try await client
            .from("email_template_settings")
            .select()
            .eq("workspace", value: workspace.rawValue)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func upsertSettings(_ upsert: EmailTemplateSettingsUpsert) async throws -> EmailTemplateSettingsRecord {
        try await client
            .from("email_template_settings")
            .upsert(upsert)
            .select()
            .single()
            .execute()
            .value
    }
}
