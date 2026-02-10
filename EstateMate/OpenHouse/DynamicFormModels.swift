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
    case name
}

enum TextCase: String, Codable, CaseIterable {
    case none
    case upper
    case lower

    var title: String {
        switch self {
        case .none: return "默认"
        case .upper: return "全大写"
        case .lower: return "全小写"
        }
    }
}

enum NameFormat: String, Codable, CaseIterable {
    case fullName
    case firstLast
    case firstMiddleLast

    var title: String {
        switch self {
        case .fullName: return "Full Name"
        case .firstLast: return "First + Last"
        case .firstMiddleLast: return "First + Middle + Last"
        }
    }
}

enum PhoneFormat: String, Codable, CaseIterable {
    case plain
    case withCountryCode

    var title: String {
        switch self {
        case .plain: return "不带区号"
        case .withCountryCode: return "带区号"
        }
    }
}

struct FormField: Codable, Identifiable, Hashable {
    var id: String { key }

    /// For most field types, this is the value key stored in submission JSON.
    /// For `.name`, this is a stable identifier; `nameKeys` holds the actual storage keys.
    var key: String
    var label: String
    var type: FormFieldType
    var required: Bool

    // For select
    var options: [String]?

    // For text
    var textCase: TextCase?

    // For name
    var nameFormat: NameFormat?
    var nameKeys: [String]?

    // For phone
    var phoneFormat: PhoneFormat?
    var phoneKeys: [String]?
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
    var location: String?
    var startsAt: Date?

    /// Scheduled end time (planning only). Does NOT decide ended/ongoing.
    var endsAt: Date?

    /// Manual ended flag. If non-nil -> ended. If nil -> ongoing.
    var endedAt: Date?

    var host: String?
    var assistant: String?

    var formId: UUID
    var isActive: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case location
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case endedAt = "ended_at"
        case host
        case assistant
        case formId = "form_id"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct OpenHouseEventInsertV2: Encodable {
    var title: String
    var location: String?
    var startsAt: Date?

    /// Scheduled end time (planning only).
    var endsAt: Date?

    /// Manual ended flag; created events default to ongoing.
    var endedAt: Date? = nil

    var host: String?
    var assistant: String?

    var formId: UUID
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case location
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case endedAt = "ended_at"
        case host
        case assistant
        case formId = "form_id"
        case isActive = "is_active"
    }
}

struct OpenHouseEventUpdateV2: Encodable {
    var title: String
    var location: String?
    var startsAt: Date?

    /// Scheduled end time (planning only).
    var endsAt: Date?

    var host: String?
    var assistant: String?
    var formId: UUID

    enum CodingKeys: String, CodingKey {
        case title
        case location
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case host
        case assistant
        case formId = "form_id"
    }

    /// PostgREST 的 update：如果 Encodable 里某个 optional 是 nil，默认会「省略 key」，
    /// 这会导致数据库列不会被清空（例如 ends_at 无法从有值改回 NULL）。
    /// 这里显式 encodeNil，让 nil 也会写入 JSON null，从而真正更新为 NULL。
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(title, forKey: .title)
        try container.encode(formId, forKey: .formId)

        if let location { try container.encode(location, forKey: .location) } else { try container.encodeNil(forKey: .location) }
        if let startsAt { try container.encode(startsAt, forKey: .startsAt) } else { try container.encodeNil(forKey: .startsAt) }
        if let endsAt { try container.encode(endsAt, forKey: .endsAt) } else { try container.encodeNil(forKey: .endsAt) }
        if let host { try container.encode(host, forKey: .host) } else { try container.encodeNil(forKey: .host) }
        if let assistant { try container.encode(assistant, forKey: .assistant) } else { try container.encodeNil(forKey: .assistant) }
    }
}

struct OpenHouseEventEndedAtPatch: Encodable {
    var endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case endedAt = "ended_at"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let endedAt {
            try container.encode(endedAt, forKey: .endedAt)
        } else {
            try container.encodeNil(forKey: .endedAt)
        }
    }
}

struct SubmissionV2: Codable, Identifiable, Hashable {
    let id: UUID
    let eventId: UUID
    /// Snapshot of which form template was used when submitting.
    let formId: UUID?
    let ownerId: UUID?
    let data: [String: String]
    let tags: [String]?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case formId = "form_id"
        case ownerId = "owner_id"
        case data
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SubmissionInsertV2: Encodable {
    let eventId: UUID
    let formId: UUID?
    let data: [String: String]

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case formId = "form_id"
        case data
    }
}

struct SubmissionUpdateV2: Encodable {
    let data: [String: String]?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case data
        case tags
    }
}

struct OpenHouseTag: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerId: UUID?
    let name: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case createdAt = "created_at"
    }
}

struct OpenHouseTagInsert: Encodable {
    let name: String
}
