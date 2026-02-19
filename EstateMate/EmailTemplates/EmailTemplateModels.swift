//
//  EmailTemplateModels.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import Foundation

enum EstateMateWorkspaceKind: String, Codable, CaseIterable, Hashable {
    case crm
    case openhouse

    var title: String {
        switch self {
        case .crm: return "客户管理"
        case .openhouse: return "活动策划"
        }
    }
}

struct EmailTemplateVariable: Codable, Hashable, Identifiable {
    var id: String { key }

    /// Variable key used in templates, e.g. {{client_name}}
    var key: String

    /// What the user should fill when previewing/sending.
    /// (Previously called "显示名".)
    var label: String

    /// Legacy: example value used for preview. (We no longer require input in UI.)
    var example: String

    /// Optional description (future)
    var desc: String?

    init(key: String, label: String, example: String = "", desc: String? = nil) {
        self.key = key
        self.label = label
        self.example = example
        self.desc = desc
    }
}

struct EmailTemplateRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let createdBy: UUID?

    var workspace: EstateMateWorkspaceKind
    var name: String
    var subject: String
    var body: String
    var variables: [EmailTemplateVariable]

    /// Optional per-template sender display name. When empty, fallback to workspace settings.
    var fromName: String?

    var isArchived: Bool

    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy = "created_by"
        case workspace
        case name
        case subject
        case body
        case variables
        case fromName = "from_name"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct EmailTemplateInsert: Encodable {
    var workspace: EstateMateWorkspaceKind
    var name: String
    var subject: String
    var body: String
    var variables: [EmailTemplateVariable]
    var fromName: String?

    enum CodingKeys: String, CodingKey {
        case workspace
        case name
        case subject
        case body
        case variables
        case fromName = "from_name"
    }
}

struct EmailTemplateUpdate: Encodable {
    var workspace: EstateMateWorkspaceKind?
    var name: String?
    var subject: String?
    var body: String?
    var variables: [EmailTemplateVariable]?
    var fromName: String?
    var isArchived: Bool?

    enum CodingKeys: String, CodingKey {
        case workspace
        case name
        case subject
        case body
        case variables
        case fromName = "from_name"
        case isArchived = "is_archived"
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let workspace { try c.encode(workspace, forKey: .workspace) }
        if let name { try c.encode(name, forKey: .name) }
        if let subject { try c.encode(subject, forKey: .subject) }
        if let body { try c.encode(body, forKey: .body) }
        if let variables { try c.encode(variables, forKey: .variables) }
        if let fromName { try c.encode(fromName, forKey: .fromName) }
        if let isArchived { try c.encode(isArchived, forKey: .isArchived) }
    }
}

enum EmailTemplateRenderer {
    static func render(_ text: String, variables: [EmailTemplateVariable], overrides: [String: String] = [:]) -> String {
        var result = text

        // 1) Built-in: always allow direct overrides, even if the key isn't declared in variables.
        // This supports "固定变量" like {{firstname}} / {{address}} without requiring the user to add them.
        for (rawKey, rawValue) in overrides {
            let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            let token = "{{\(key)}}"
            result = result.replacingOccurrences(of: token, with: rawValue)
        }

        // 2) Declared variables: fallback to example when no override is provided.
        for v in variables {
            let key = v.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            let token = "{{\(key)}}"
            let value = overrides[key] ?? v.example
            result = result.replacingOccurrences(of: token, with: value)
        }

        return result
    }

    static func normalizeKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        // keep simple: lowercase + allow a-z 0-9 _
        let lower = trimmed.lowercased()
        let allowed = lower.filter { ch in
            (ch >= "a" && ch <= "z") || (ch >= "0" && ch <= "9") || ch == "_"
        }
        return allowed
    }
}
