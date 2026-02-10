//
//  CRMCustomFieldsModels.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation

struct CRMContactCustomField: Codable, Identifiable, Hashable {
    let id: UUID
    let contactId: UUID
    let eventId: UUID?
    let submissionId: UUID?

    let eventTitle: String
    let eventLocation: String
    let submittedAt: Date?

    let fieldKey: String
    let fieldLabel: String
    let valueText: String

    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case eventId = "event_id"
        case submissionId = "submission_id"
        case eventTitle = "event_title"
        case eventLocation = "event_location"
        case submittedAt = "submitted_at"
        case fieldKey = "field_key"
        case fieldLabel = "field_label"
        case valueText = "value_text"
        case createdAt = "created_at"
    }
}

struct CRMContactCustomFieldUpsert: Encodable {
    let contactId: UUID
    let eventId: UUID?
    let submissionId: UUID?
    let eventTitle: String
    let eventLocation: String
    let submittedAt: Date?
    let fieldKey: String
    let fieldLabel: String
    let valueText: String

    enum CodingKeys: String, CodingKey {
        case contactId = "contact_id"
        case eventId = "event_id"
        case submissionId = "submission_id"
        case eventTitle = "event_title"
        case eventLocation = "event_location"
        case submittedAt = "submitted_at"
        case fieldKey = "field_key"
        case fieldLabel = "field_label"
        case valueText = "value_text"
    }
}
