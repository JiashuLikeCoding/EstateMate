//
//  OpenHouseModels.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import Foundation

struct OpenHouseEvent: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var isActive: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct OpenHouseSubmission: Codable, Identifiable, Hashable {
    let id: UUID
    let eventId: UUID
    var fullName: String
    var phone: String
    var email: String
    var notes: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case fullName = "full_name"
        case phone
        case email
        case notes
        case createdAt = "created_at"
    }
}

struct OpenHouseEventInsert: Encodable {
    var title: String
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case isActive = "is_active"
    }
}

struct OpenHouseSubmissionInsert: Encodable {
    let eventId: UUID
    var fullName: String
    var phone: String
    var email: String
    var notes: String

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case fullName = "full_name"
        case phone
        case email
        case notes
    }
}
