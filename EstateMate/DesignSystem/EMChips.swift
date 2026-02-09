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
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isOn ? EMTheme.accent : EMTheme.ink2)
            .background(
                Capsule(style: .continuous)
                    .fill(isOn ? EMTheme.accent.opacity(0.12) : Color.white)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(EMTheme.line, lineWidth: 1)
            )
    }
}
