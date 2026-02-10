//
//  CursorAwareTextView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI
import UIKit

/// A UITextView-backed editor that exposes selection so we can insert tokens at the cursor position.
struct CursorAwareTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        // Keep the cursor in sync (avoid feedback loop while the user is dragging selection)
        if !context.coordinator.isUpdatingSelectionFromUser {
            let safeLoc = min(max(selection.location, 0), (uiView.text as NSString).length)
            let safeLen = min(max(selection.length, 0), (uiView.text as NSString).length - safeLoc)
            let safe = NSRange(location: safeLoc, length: safeLen)
            if uiView.selectedRange != safe {
                uiView.selectedRange = safe
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selection: $selection)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var selection: NSRange

        var isUpdatingSelectionFromUser = false

        init(text: Binding<String>, selection: Binding<NSRange>) {
            _text = text
            _selection = selection
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            isUpdatingSelectionFromUser = true
            selection = textView.selectedRange
            DispatchQueue.main.async { [weak self] in
                self?.isUpdatingSelectionFromUser = false
            }
        }
    }
}
