//
//  CRMTasksModels.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation

struct CRMTask: Codable, Identifiable, Equatable {
    var id: UUID
    var contactId: UUID?
    var title: String
    var notes: String
    var dueAt: Date?
    var isDone: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case title
        case notes
        case dueAt = "due_at"
        case isDone = "is_done"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CRMTaskInsert: Codable {
    var contactId: UUID?
    var title: String
    var notes: String
    var dueAt: Date?

    enum CodingKeys: String, CodingKey {
        case contactId = "contact_id"
        case title
        case notes
        case dueAt = "due_at"
    }
}

struct CRMTaskUpdate: Codable {
    var contactId: UUID?
    var title: String?
    var notes: String?
    var dueAt: Date?
    var isDone: Bool?

    enum CodingKeys: String, CodingKey {
        case contactId = "contact_id"
        case title
        case notes
        case dueAt = "due_at"
        case isDone = "is_done"
    }
}
