//
//  CRMTaskContactPickerView+Helpers.swift
//  EstateMate
//

import Foundation

func crmContactTitle(_ c: CRMContact) -> String {
    let n = c.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !n.isEmpty { return n }
    if !c.email.isEmpty { return c.email }
    if !c.phone.isEmpty { return c.phone }
    return "未命名客户"
}

func crmContactSubtitle(_ c: CRMContact) -> String? {
    var parts: [String] = []
    if !c.email.isEmpty { parts.append(c.email) }
    if !c.phone.isEmpty { parts.append(c.phone) }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
}

func crmContactMetaLine(_ c: CRMContact) -> String? {
    var parts: [String] = []
    parts.append("阶段：\(c.stage.displayName)")
    parts.append("来源：\(c.source.displayName)")
    if let tags = c.tags, !tags.isEmpty {
        parts.append("标签：\(tags.prefix(3).joined(separator: ","))")
    }
    return parts.isEmpty ? nil : parts.joined(separator: "  ")
}
