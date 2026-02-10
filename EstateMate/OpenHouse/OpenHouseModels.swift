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

struct OpenHouseLockClaimResult: Codable, Hashable {
    let status: String
    let ownerId: UUID
    let deviceId: String
    let deviceName: String?
    let existingDeviceId: String?
    let existingDeviceName: String?
    let existingLastSeen: Date?

    enum CodingKeys: String, CodingKey {
        case status
        case ownerId = "owner_id"
        case deviceId = "device_id"
        case deviceName = "device_name"
        case existingDeviceId = "existing_device_id"
        case existingDeviceName = "existing_device_name"
        case existingLastSeen = "existing_last_seen"
    }

    var isInUseByOtherDevice: Bool {
        status == "in_use" && existingDeviceId != nil && existingDeviceId != deviceId
    }
}
