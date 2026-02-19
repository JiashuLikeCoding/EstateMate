//
//  DynamicFormModels.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import Foundation
import Supabase

enum FormFieldType: String, Codable, CaseIterable {
    // Input fields
    case text
    case multilineText
    case phone
    case email
    case select
    case dropdown
    case multiSelect
    case checkbox
    case name

    // Auto-fill fields (stored into submission.data like text)
    // - date/time: defaults to "now" when the filling screen opens
    // - address: defaults to the event location
    case date
    case time
    case address

    // Decoration / layout fields (display-only; NEVER stored into submission.data)
    case sectionTitle
    case sectionSubtitle
    case divider

    /// Layout: join adjacent fields into the same row (large screens only).
    /// This field itself has no label and does not store any value.
    case splice
}

enum TextCase: String, Codable, CaseIterable {
    case none
    case upper
    case lower

    var title: String {
        switch self {
        case .none: return "默认"
        case .upper: return "全大写"
        case .lower: return "全小写"
        }
    }
}

enum NameFormat: String, Codable, CaseIterable {
    case fullName
    case firstLast
    case firstMiddleLast

    var title: String {
        switch self {
        case .fullName: return "Full Name"
        case .firstLast: return "First + Last"
        case .firstMiddleLast: return "First + Middle + Last"
        }
    }
}

enum PhoneFormat: String, Codable, CaseIterable {
    case plain
    case withCountryCode

    var title: String {
        switch self {
        case .plain: return "不带区号"
        case .withCountryCode: return "带区号"
        }
    }
}

enum SelectStyle: String, Codable, CaseIterable {
    case dropdown
    case dot

    var title: String {
        switch self {
        case .dropdown: return "下拉"
        case .dot: return "圆点"
        }
    }
}

enum MultiSelectStyle: String, Codable, CaseIterable {
    case chips
    case checklist
    case dropdown

    var title: String {
        switch self {
        case .chips: return "Chips"
        case .checklist: return "列表"
        case .dropdown: return "下拉"
        }
    }
}

struct FormVisibilityRule: Codable, Hashable {
    enum Op: String, Codable, CaseIterable {
        case equals
        case notEquals

        var title: String {
            switch self {
            case .equals: return "等于"
            case .notEquals: return "不等于"
            }
        }
    }

    /// Which field controls visibility (key).
    var dependsOnKey: String

    /// equals / notEquals
    var op: Op

    /// Target value (stored as a string). For checkbox, use "是" / "否".
    var value: String

    /// If true, when the field becomes hidden, clear its value from submission.
    var clearOnHide: Bool?

    init(dependsOnKey: String, op: Op, value: String, clearOnHide: Bool? = true) {
        self.dependsOnKey = dependsOnKey
        self.op = op
        self.value = value
        self.clearOnHide = clearOnHide
    }
}

struct FormField: Codable, Identifiable, Hashable {
    var id: String { key }

    init(
        key: String,
        label: String,
        type: FormFieldType,
        required: Bool,
        options: [String]? = nil,
        selectStyle: SelectStyle? = nil,
        multiSelectStyle: MultiSelectStyle? = nil,
        textCase: TextCase? = nil,
        nameFormat: NameFormat? = nil,
        nameKeys: [String]? = nil,
        phoneFormat: PhoneFormat? = nil,
        phoneKeys: [String]? = nil,
        subtitle: String? = nil,
        placeholder: String? = nil,
        placeholders: [String]? = nil,
        isEditable: Bool? = nil,
        fontSize: Double? = nil,
        dividerDashed: Bool? = nil,
        dividerThickness: Double? = nil,
        decorationColorKey: String? = nil,
        visibleWhen: FormVisibilityRule? = nil
    ) {
        self.key = key
        self.label = label
        self.type = type
        self.required = required
        self.options = options
        self.selectStyle = selectStyle
        self.multiSelectStyle = multiSelectStyle
        self.textCase = textCase
        self.nameFormat = nameFormat
        self.nameKeys = nameKeys
        self.phoneFormat = phoneFormat
        self.phoneKeys = phoneKeys
        self.subtitle = subtitle
        self.placeholder = placeholder
        self.placeholders = placeholders
        self.isEditable = isEditable
        self.fontSize = fontSize
        self.dividerDashed = dividerDashed
        self.dividerThickness = dividerThickness
        self.decorationColorKey = decorationColorKey
        self.visibleWhen = visibleWhen
    }

    /// For most field types, this is the value key stored in submission JSON.
    /// For `.name`, this is a stable identifier; `nameKeys` holds the actual storage keys.
    var key: String

    /// For input fields: shown as the field title.
    /// For decoration fields: used as the displayed text (title/subtitle). For `.divider` it is ignored.
    var label: String

    var type: FormFieldType

    /// Only meaningful for input fields. Decoration fields should always be `false`.
    var required: Bool

    // For select / multi-select
    var options: [String]?

    /// Only for `.select`.
    /// - dropdown: collapsed row + inline expanded list
    /// - dot: dot + text options displayed directly
    var selectStyle: SelectStyle?

    /// Only for `.multiSelect`.
    /// - chips: chips displayed directly
    /// - checklist: checkbox list
    /// - dropdown: collapsed row + inline expanded list
    var multiSelectStyle: MultiSelectStyle?

    // For text
    var textCase: TextCase?

    // For name
    var nameFormat: NameFormat?
    var nameKeys: [String]?

    // For phone
    var phoneFormat: PhoneFormat?
    var phoneKeys: [String]?

    /// Optional helper text shown below the field (currently used by `.checkbox`).
    var subtitle: String?

    /// Placeholder text shown inside the input.
    /// For composite fields (name/phone with country code), use `placeholders`.
    var placeholder: String?

    /// Composite placeholders (e.g. name: first/last/middle; phone: code/number).
    var placeholders: [String]?

    /// If false, the field is shown read-only in guest fill / preview / submission edit.
    /// Nil = defaults to true (backward compatible).
    var isEditable: Bool?

    // MARK: - Decoration / layout options

    /// For `.sectionTitle` / `.sectionSubtitle`: font size (points).
    /// If nil, renderer uses a sensible default.
    var fontSize: Double?

    /// For `.divider`: whether to use dashed line.
    var dividerDashed: Bool?

    /// For `.divider`: line thickness (points).
    var dividerThickness: Double?

    /// For `.sectionTitle` / `.sectionSubtitle` / `.divider`: color key (theme-mapped).
    /// Nil means renderer uses default per field type.
    var decorationColorKey: String?

    /// Conditional visibility.
    /// If nil -> always visible.
    var visibleWhen: FormVisibilityRule?
}

struct FormSchema: Codable, Hashable {
    var version: Int
    var fields: [FormField]

    /// Display-only configuration (safe to store in forms.schema). NEVER persisted to submissions.
    var presentation: FormPresentation?
}

struct FormPresentation: Codable, Hashable {
    var background: FormBackground?
}

enum FormBackgroundKind: String, Codable, CaseIterable {
    case builtIn
    case custom
}

struct FormBackground: Codable, Hashable {
    var kind: FormBackgroundKind

    /// For built-in backgrounds.
    var builtInKey: String?

    /// For custom backgrounds stored in Supabase Storage.
    /// Store the storage path (e.g. "form_backgrounds/<formId>/<uuid>.jpg").
    var storagePath: String?

    /// 0...1
    var opacity: Double

    static var `default`: FormBackground {
        .init(kind: .builtIn, builtInKey: "paper", storagePath: nil, opacity: 0.12)
    }
}

struct FormRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerId: UUID?
    var name: String
    var schema: FormSchema
    var isArchived: Bool?
    var archivedAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case schema
        case isArchived = "is_archived"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
    }
}

/// Lightweight list row model for forms (does NOT include schema).
struct FormSummary: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var isArchived: Bool?
    var archivedAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isArchived = "is_archived"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
    }
}

struct FormInsert: Encodable {
    var name: String
    var schema: FormSchema
}

struct OpenHouseEventV2: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerId: UUID?

    var title: String
    var location: String?
    var startsAt: Date?

    /// Scheduled end time (planning only). Does NOT decide ended/ongoing.
    var endsAt: Date?

    /// Manual ended flag. If non-nil -> ended. If nil -> ongoing.
    var endedAt: Date?

    var host: String?
    var assistant: String?

    var formId: UUID

    /// Optional default email template for this event (e.g. follow-up email).
    var emailTemplateId: UUID?

    var isActive: Bool
    var isArchived: Bool?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case location
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case endedAt = "ended_at"
        case host
        case assistant
        case formId = "form_id"
        case emailTemplateId = "email_template_id"
        case isActive = "is_active"
        case isArchived = "is_archived"
        case createdAt = "created_at"
    }
}

struct OpenHouseEventInsertV2: Encodable {
    var title: String
    var location: String?
    var startsAt: Date?

    /// Scheduled end time (planning only).
    var endsAt: Date?

    /// Manual ended flag; created events default to ongoing.
    var endedAt: Date? = nil

    var host: String?
    var assistant: String?

    var formId: UUID
    var emailTemplateId: UUID?
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case location
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case endedAt = "ended_at"
        case host
        case assistant
        case formId = "form_id"
        case emailTemplateId = "email_template_id"
        case isActive = "is_active"
    }
}

struct OpenHouseEventUpdateV2: Encodable {
    var title: String
    var location: String?
    var startsAt: Date?

    /// Scheduled end time (planning only).
    var endsAt: Date?

    var host: String?
    var assistant: String?
    var formId: UUID

    /// Optional default email template for this event.
    var emailTemplateId: UUID?

    enum CodingKeys: String, CodingKey {
        case title
        case location
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case host
        case assistant
        case formId = "form_id"
        case emailTemplateId = "email_template_id"
    }

    /// PostgREST 的 update：如果 Encodable 里某个 optional 是 nil，默认会「省略 key」，
    /// 这会导致数据库列不会被清空（例如 ends_at 无法从有值改回 NULL）。
    /// 这里显式 encodeNil，让 nil 也会写入 JSON null，从而真正更新为 NULL。
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(title, forKey: .title)
        try container.encode(formId, forKey: .formId)

        if let location { try container.encode(location, forKey: .location) } else { try container.encodeNil(forKey: .location) }
        if let startsAt { try container.encode(startsAt, forKey: .startsAt) } else { try container.encodeNil(forKey: .startsAt) }
        if let endsAt { try container.encode(endsAt, forKey: .endsAt) } else { try container.encodeNil(forKey: .endsAt) }
        if let host { try container.encode(host, forKey: .host) } else { try container.encodeNil(forKey: .host) }
        if let assistant { try container.encode(assistant, forKey: .assistant) } else { try container.encodeNil(forKey: .assistant) }
        if let emailTemplateId { try container.encode(emailTemplateId, forKey: .emailTemplateId) } else { try container.encodeNil(forKey: .emailTemplateId) }
    }
}

struct OpenHouseEventEndedAtPatch: Encodable {
    var endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case endedAt = "ended_at"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let endedAt {
            try container.encode(endedAt, forKey: .endedAt)
        } else {
            try container.encodeNil(forKey: .endedAt)
        }
    }
}

struct SubmissionV2: Codable, Identifiable, Hashable {
    let id: UUID
    let eventId: UUID
    /// Snapshot of which form template was used when submitting.
    let formId: UUID?
    /// Optional link to CRM contact (best-effort; may be nil for legacy submissions).
    let contactId: UUID?
    let ownerId: UUID?
    let data: [String: AnyJSON]
    let tags: [String]?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case formId = "form_id"
        case contactId = "contact_id"
        case ownerId = "owner_id"
        case data
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SubmissionInsertV2: Encodable {
    let eventId: UUID
    let formId: UUID?
    let data: [String: AnyJSON]

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case formId = "form_id"
        case data
    }
}

struct SubmissionUpdateV2: Encodable {
    let data: [String: AnyJSON]?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case data
        case tags
    }
}

struct OpenHouseTag: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerId: UUID?
    let name: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case createdAt = "created_at"
    }
}

struct OpenHouseTagInsert: Encodable {
    let name: String
}
