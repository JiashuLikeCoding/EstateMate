//
//  CRMModels.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation

struct CRMContact: Codable, Identifiable, Equatable {
    var id: UUID
    var fullName: String
    var phone: String
    var email: String
    var notes: String
    var tags: [String]?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case phone
        case email
        case notes
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CRMContactInsert: Codable {
    var fullName: String
    var phone: String
    var email: String
    var notes: String
    var tags: [String]?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case phone
        case email
        case notes
        case tags
    }
}

struct CRMContactUpdate: Codable {
    var fullName: String?
    var phone: String?
    var email: String?
    var notes: String?
    var tags: [String]?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case phone
        case email
        case notes
        case tags
    }
}
