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

    /// Mature, muted CRM blue.
    static let crmAccent = Color(red: 0.16, green: 0.36, blue: 0.54)

    /// Mature, muted system picker accent.
    static let systemAccent = Color(red: 0.38, green: 0.28, blue: 0.52)

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
        if key.hasPrefix("#"), let c = colorFromHex(key) {
            return c
        }

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
        if key.hasPrefix("#") { return "自定义" }
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

    // MARK: - Hex colors (custom)
    static func colorFromHex(_ hex: String) -> Color? {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("#") else { return nil }
        let h = String(s.dropFirst())
        guard h.count == 6 else { return nil }

        let rStr = String(h.prefix(2))
        let gStr = String(h.dropFirst(2).prefix(2))
        let bStr = String(h.dropFirst(4).prefix(2))

        let rInt = Int(rStr, radix: 16) ?? -1
        let gInt = Int(gStr, radix: 16) ?? -1
        let bInt = Int(bStr, radix: 16) ?? -1
        guard rInt >= 0, gInt >= 0, bInt >= 0 else { return nil }

        return Color(
            red: Double(rInt) / 255.0,
            green: Double(gInt) / 255.0,
            blue: Double(bInt) / 255.0
        )
    }

    static func hexFromColor(_ color: Color) -> String? {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let rr = Int(round(r * 255))
        let gg = Int(round(g * 255))
        let bb = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", rr, gg, bb)
        #else
        return nil
        #endif
    }

    // MARK: - Metrics
    static let radius: CGFloat = 16
    static let radiusSmall: CGFloat = 12
    static let padding: CGFloat = 20
}
