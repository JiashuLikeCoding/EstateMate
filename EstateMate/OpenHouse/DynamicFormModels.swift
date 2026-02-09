//
//  DynamicFormModels.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import Foundation

enum FormFieldType: String, Codable, CaseIterable {
    case text
    case phone
    case email
    case select
}

struct FormField: Codable, Identifiable, Hashable {
    var id: String { key }

    var key: String
    var label: String
    var type: FormFieldType
    var required: Bool
    var options: [String]?
}

struct FormSchema: Codable, Hashable {
    var version: Int
    var fields: [FormField]
}

struct FormRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerId: UUID?
    var name: String
    var schema: FormSchema
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case schema
        case createdAt = "created_at"
    }
}

struct FormInsert: Encodable {
    var name: String
    var schema: FormSchema
}

struct OpenHouseEventV2: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerId: UUID?
    var title: String
    var formId: UUID
    var isActive: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case formId = "form_id"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct OpenHouseEventInsertV2: Encodable {
    var title: String
    var formId: UUID
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case formId = "form_id"
        case isActive = "is_active"
    }
}

struct SubmissionV2: Codable, Identifiable, Hashable {
    let id: UUID
    let eventId: UUID
    let ownerId: UUID?
    let data: [String: String]
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case ownerId = "owner_id"
        case data
        case createdAt = "created_at"
    }
}

struct SubmissionInsertV2: Encodable {
    let eventId: UUID
    let data: [String: String]

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case data
    }
}
