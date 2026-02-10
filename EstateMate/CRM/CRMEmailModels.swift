//
//  CRMEmailModels.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation

enum CRMEmailDirection: String, Codable, CaseIterable, Hashable {
    case outbound
    case inbound

    var title: String {
        switch self {
        case .outbound: return "发出"
        case .inbound: return "收到"
        }
    }
}

struct CRMEmailLog: Codable, Identifiable, Hashable {
    let id: UUID
    let createdBy: UUID?
    let contactId: UUID

    var direction: CRMEmailDirection
    var subject: String
    var body: String
    var sentAt: Date?

    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy = "created_by"
        case contactId = "contact_id"
        case direction
        case subject
        case body
        case sentAt = "sent_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CRMEmailLogInsert: Encodable {
    let contactId: UUID
    let direction: CRMEmailDirection
    let subject: String
    let body: String
    let sentAt: Date?

    enum CodingKeys: String, CodingKey {
        case contactId = "contact_id"
        case direction
        case subject
        case body
        case sentAt = "sent_at"
    }
}

struct CRMEmailLogUpdate: Encodable {
    let direction: CRMEmailDirection?
    let subject: String?
    let body: String?
    let sentAt: Date?

    enum CodingKeys: String, CodingKey {
        case direction
        case subject
        case body
        case sentAt = "sent_at"
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let direction { try c.encode(direction, forKey: .direction) }
        if let subject { try c.encode(subject, forKey: .subject) }
        if let body { try c.encode(body, forKey: .body) }
        if let sentAt { try c.encode(sentAt, forKey: .sentAt) } else { try c.encodeNil(forKey: .sentAt) }
    }
}
