//
//  CursorAwareTextField.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-10.
//

import SwiftUI
import UIKit

/// A UITextField-backed editor that exposes selection so we can insert tokens at the cursor position.
struct CursorAwareTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var isFocused: Bool

    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var autocorrectionType: UITextAutocorrectionType = .default

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.font = UIFont.preferredFont(forTextStyle: .callout)
        tf.adjustsFontForContentSizeCategory = true
        tf.placeholder = placeholder
        tf.keyboardType = keyboardType
        tf.autocapitalizationType = autocapitalization
        tf.autocorrectionType = autocorrectionType
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        uiView.placeholder = placeholder
        uiView.keyboardType = keyboardType
        uiView.autocapitalizationType = autocapitalization
        uiView.autocorrectionType = autocorrectionType

        // Keep focus in sync (best-effort).
        if isFocused, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }

        // Keep selection in sync.
        let ns = (uiView.text ?? "") as NSString
        let safeLoc = min(max(selection.location, 0), ns.length)
        let safeLen = min(max(selection.length, 0), ns.length - safeLoc)
        let safe = NSRange(location: safeLoc, length: safeLen)

        if let r = uiView.selectedTextRange {
            let start = uiView.offset(from: uiView.beginningOfDocument, to: r.start)
            let end = uiView.offset(from: uiView.beginningOfDocument, to: r.end)
            let current = NSRange(location: start, length: max(0, end - start))

            if current != safe {
                if let startPos = uiView.position(from: uiView.beginningOfDocument, offset: safe.location),
                   let endPos = uiView.position(from: startPos, offset: safe.length) {
                    uiView.selectedTextRange = uiView.textRange(from: startPos, to: endPos)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selection: $selection, isFocused: $isFocused)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var selection: NSRange
        @Binding var isFocused: Bool

        init(text: Binding<String>, selection: Binding<NSRange>, isFocused: Binding<Bool>) {
            _text = text
            _selection = selection
            _isFocused = isFocused
        }

        @objc func editingChanged(_ sender: UITextField) {
            text = sender.text ?? ""
            updateSelection(from: sender)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused = true
            updateSelection(from: textField)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused = false
            updateSelection(from: textField)
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            updateSelection(from: textField)
        }

        private func updateSelection(from tf: UITextField) {
            guard let r = tf.selectedTextRange else { return }
            let start = tf.offset(from: tf.beginningOfDocument, to: r.start)
            let end = tf.offset(from: tf.beginningOfDocument, to: r.end)
            selection = NSRange(location: start, length: max(0, end - start))
        }
    }
}
