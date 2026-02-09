//
//  Workspace.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import Foundation

enum Workspace: String, CaseIterable, Identifiable {
    case openHouse
    case crm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openHouse: return "OpenHouse"
        case .crm: return "CRM"
        }
    }

    var subtitle: String {
        switch self {
        case .openHouse: return "Guest-facing experience"
        case .crm: return "Internal management"
        }
    }
}
