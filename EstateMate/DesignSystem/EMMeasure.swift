//
//  EMMeasure.swift
//  EstateMate
//

import SwiftUI

private struct EMHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    /// Reads the rendered height of this view.
    func emReadHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: EMHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(EMHeightPreferenceKey.self, perform: onChange)
    }
}
