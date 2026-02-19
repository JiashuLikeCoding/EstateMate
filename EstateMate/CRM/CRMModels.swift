//
//  CRMModels.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation

enum CRMContactStage: String, CaseIterable, Codable, Equatable {
    case newLead = "新线索"
    case contacted = "已联系"
    case viewing = "已带看"
    case negotiating = "谈判中"
    case won = "已成交"
    case lost = "已流失"

    var displayName: String { rawValue }
}

enum CRMContactSource: String, CaseIterable, Codable, Equatable {
    // NOTE: raw values are persisted; do NOT change them lightly.
    case manual = "手动"
    case openHouse = "开放日"

    var displayName: String {
        switch self {
        case .manual: return "手动"
        case .openHouse: return "活动策划"
        }
    }
}

struct CRMContact: Codable, Identifiable, Equatable {
    var id: UUID
    var fullName: String
    var phone: String
    var email: String
    var notes: String
    var address: String
    var tags: [String]?
    var stage: CRMContactStage
    var source: CRMContactSource
    var lastContactedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case phone
        case email
        case notes
        case address
        case tags
        case stage
        case source
        case lastContactedAt = "last_contacted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CRMContactInsert: Codable {
    var fullName: String
    var phone: String
    var email: String
    var notes: String
    var address: String
    var tags: [String]?
    var stage: CRMContactStage
    var source: CRMContactSource
    var lastContactedAt: Date?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case phone
        case email
        case notes
        case address
        case tags
        case stage
        case source
        case lastContactedAt = "last_contacted_at"
    }
}

struct CRMContactUpdate: Codable {
    var fullName: String?
    var phone: String?
    var email: String?
    var notes: String?
    var address: String?
    var tags: [String]?
    var stage: CRMContactStage?
    var source: CRMContactSource?
    var lastContactedAt: Date?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case phone
        case email
        case notes
        case address
        case tags
        case stage
        case source
        case lastContactedAt = "last_contacted_at"
    }
}
