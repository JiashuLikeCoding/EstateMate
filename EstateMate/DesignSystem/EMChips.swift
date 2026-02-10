//
//  EMChips.swift
//  EstateMate
//

import SwiftUI

struct EMChip: View {
    let text: String
    var isOn: Bool

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(isOn ? EMTheme.accent : EMTheme.ink2)
            .background(
                Capsule(style: .continuous)
                    .fill(isOn ? EMTheme.accent.opacity(0.10) : EMTheme.paper2)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isOn ? EMTheme.accent.opacity(0.35) : EMTheme.line, lineWidth: 1)
            )
    }
}
