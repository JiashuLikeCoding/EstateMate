//
//  EmailTemplateSettingsModels.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation

struct EmailTemplateSettingsRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let createdBy: UUID?
    var workspace: EstateMateWorkspaceKind

    var footerHTML: String
    var footerText: String

    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy = "created_by"
        case workspace
        case footerHTML = "footer_html"
        case footerText = "footer_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct EmailTemplateSettingsUpsert: Encodable {
    var workspace: EstateMateWorkspaceKind
    var footerHTML: String
    var footerText: String

    enum CodingKeys: String, CodingKey {
        case workspace
        case footerHTML = "footer_html"
        case footerText = "footer_text"
    }
}
