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
        case .openHouse: return "活动策划"
        case .crm: return "客户管理"
        }
    }

    var subtitle: String {
        switch self {
        case .openHouse: return "现场接待与登记"
        case .crm: return "内部管理与数据查看"
        }
    }

    var iconSystemName: String {
        switch self {
        case .openHouse: return "calendar.badge.clock"
        case .crm: return "person.2"
        }
    }
}
