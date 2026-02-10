//
//  EMTheme.swift
//  EstateMate
//
//  Minimal Japanese-inspired theme: paper background, ink text, moss accent.
//

import SwiftUI

enum EMTheme {
    // MARK: - Colors
    static let paper = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let paper2 = Color(red: 0.95, green: 0.95, blue: 0.94)
    static let ink = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let ink2 = Color(red: 0.35, green: 0.35, blue: 0.35)

    /// Moss green (subtle, premium)
    static let accent = Color(red: 0.20, green: 0.52, blue: 0.42)

    static let line = Color.black.opacity(0.08)

    // MARK: - Decoration colors (persisted as keys in form schema)
    /// Stable, schema-friendly keys.
    enum DecorationColorKey: String, CaseIterable {
        case `default`
        case ink
        case ink2
        case accent
        case red
        case blue
    }

    static func decorationColor(for key: String) -> Color? {
        switch key {
        case DecorationColorKey.default.rawValue:
            return nil
        case DecorationColorKey.ink.rawValue:
            return ink
        case DecorationColorKey.ink2.rawValue:
            return ink2
        case DecorationColorKey.accent.rawValue:
            return accent
        case DecorationColorKey.red.rawValue:
            return .red
        case DecorationColorKey.blue.rawValue:
            return .blue
        default:
            return nil
        }
    }

    static func decorationColorTitle(for key: String) -> String {
        switch key {
        case DecorationColorKey.default.rawValue: return "默认"
        case DecorationColorKey.ink.rawValue: return "墨黑"
        case DecorationColorKey.ink2.rawValue: return "灰"
        case DecorationColorKey.accent.rawValue: return "苔绿"
        case DecorationColorKey.red.rawValue: return "红"
        case DecorationColorKey.blue.rawValue: return "蓝"
        default: return key
        }
    }

    static let decorationColorOptions: [String] = [
        DecorationColorKey.default.rawValue,
        DecorationColorKey.ink.rawValue,
        DecorationColorKey.ink2.rawValue,
        DecorationColorKey.accent.rawValue,
        DecorationColorKey.red.rawValue,
        DecorationColorKey.blue.rawValue
    ]

    // MARK: - Metrics
    static let radius: CGFloat = 16
    static let radiusSmall: CGFloat = 12
    static let padding: CGFloat = 20
}
