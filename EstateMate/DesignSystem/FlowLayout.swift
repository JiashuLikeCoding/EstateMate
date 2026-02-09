//
//  FlowLayout.swift
//  EstateMate
//
//  A simple flow layout that wraps and also caps items per row.
//  Usage:
//    FlowLayout(maxPerRow: 3, spacing: 8) {
//      ...
//    }
//

import SwiftUI

struct FlowLayout: Layout {
    let maxPerRow: Int
    let spacing: CGFloat

    init(maxPerRow: Int, spacing: CGFloat = 8) {
        self.maxPerRow = max(1, maxPerRow)
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        if width <= 0 { return .zero }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var itemsInRow = 0

        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            let shouldWrapByCount = itemsInRow >= maxPerRow
            let shouldWrapByWidth = (x > 0 && x + s.width > width)

            if shouldWrapByCount || shouldWrapByWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
                itemsInRow = 0
            }

            if x > 0 { x += spacing }
            x += s.width
            rowHeight = max(rowHeight, s.height)
            itemsInRow += 1
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        var itemsInRow = 0

        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            let shouldWrapByCount = itemsInRow >= maxPerRow
            let shouldWrapByWidth = (x > bounds.minX && x + s.width > bounds.maxX)

            if shouldWrapByCount || shouldWrapByWidth {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
                itemsInRow = 0
            }

            if x > bounds.minX { x += spacing }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: s.width, height: s.height))
            x += s.width
            rowHeight = max(rowHeight, s.height)
            itemsInRow += 1
        }
    }
}
