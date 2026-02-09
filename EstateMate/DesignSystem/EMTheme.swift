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

    // MARK: - Metrics
    static let radius: CGFloat = 16
    static let radiusSmall: CGFloat = 12
    static let padding: CGFloat = 20
}
