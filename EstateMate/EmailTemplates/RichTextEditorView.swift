//
//  RichTextEditorView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-19.
//

import SwiftUI
import UIKit

/// A lightweight WYSIWYG editor backed by UITextView + NSAttributedString.
///
/// Supported formatting (MVP): bold, italic, text color, and plain newlines.
struct RichTextEditorView: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selection: NSRange
    @Binding var isFocused: Bool

    var minHeight: CGFloat = 180

    /// Called when the user actually edits the text (not when we programmatically update it).
    var onUserEdit: (() -> Void)? = nil

    /// Highlight template variables like {{first_name}} in the editor.
    /// Note: this is editor-only; we strip this highlight before saving/export.
    var highlightVariables: Bool = true

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.isEditable = true
        tv.isSelectable = true
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        tv.textContainer.lineFragmentPadding = 0

        // Match the rest of the app's body text sizing.
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.textColor = UIColor.label

        // Auto-detect links for WYSIWYG
        tv.dataDetectorTypes = [.link]

        // Initial content (with editor-only variable highlighting)
        tv.attributedText = highlightVariables ? applyVariableHighlight(to: attributedText) : attributedText
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Compare against a stripped version because the UITextView may have editor-only highlighting.
        let currentBase = highlightVariables ? stripVariableHighlight(from: uiView.attributedText) : uiView.attributedText
        if currentBase != attributedText {
            context.coordinator.isProgrammaticChange = true
            uiView.attributedText = highlightVariables ? applyVariableHighlight(to: attributedText) : attributedText
            // Reset on next runloop so delegate changes triggered by this assignment don't count as user edits.
            DispatchQueue.main.async {
                context.coordinator.isProgrammaticChange = false
            }
        }

        if uiView.selectedRange != selection {
            uiView.selectedRange = selection
        }

        if isFocused {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        } else {
            if uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: RichTextEditorView
        var isProgrammaticChange: Bool = false

        init(parent: RichTextEditorView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            if !isProgrammaticChange {
                parent.onUserEdit?()
            }

            let raw = textView.attributedText ?? NSAttributedString(string: "")

            // Strip editor-only variable styling so we don't persist the green color into the saved HTML.
            let base = parent.highlightVariables ? stripVariableHighlight(from: raw) : raw
            parent.attributedText = base

            // Re-apply highlight for display (keeping cursor stable as much as possible).
            guard parent.highlightVariables else { return }
            let selected = textView.selectedRange
            let highlighted = applyVariableHighlight(to: base)
            if textView.attributedText != highlighted {
                isProgrammaticChange = true
                textView.attributedText = highlighted
                textView.selectedRange = selected
                DispatchQueue.main.async {
                    self.isProgrammaticChange = false
                }
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selection = textView.selectedRange
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }
    }
}

// MARK: - Editor-only variable highlighting

private func applyVariableHighlight(to attributed: NSAttributedString) -> NSAttributedString {
    guard attributed.length > 0 else { return attributed }

    let mutable = NSMutableAttributedString(attributedString: attributed)
    let s = mutable.string as NSString
    let fullRange = NSRange(location: 0, length: s.length)

    // Match {{variable_name}} tokens.
    let pattern = "\\{\\{[^{}]+\\}\\}" // simple + safe
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return attributed }

    let tokenColor = UIColor(hexString: "#0B5A2A") ?? UIColor.systemGreen
    regex.enumerateMatches(in: mutable.string, range: fullRange) { match, _, _ in
        guard let r = match?.range, r.length > 0 else { return }

        // Editor-only: deep green + bold for {{...}} tokens.
        // IMPORTANT: we strip this styling before saving/export.
        mutable.addAttribute(.foregroundColor, value: tokenColor, range: r)

        mutable.enumerateAttribute(.font, in: r, options: []) { value, subRange, _ in
            let baseFont = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            let descriptor = baseFont.fontDescriptor
            let traits = descriptor.symbolicTraits.union(.traitBold)
            if let newDescriptor = descriptor.withSymbolicTraits(traits) {
                mutable.addAttribute(.font, value: UIFont(descriptor: newDescriptor, size: baseFont.pointSize), range: subRange)
            } else {
                mutable.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: baseFont.pointSize), range: subRange)
            }
        }
    }

    return mutable
}

private func stripVariableHighlight(from attributed: NSAttributedString) -> NSAttributedString {
    guard attributed.length > 0 else { return attributed }

    let mutable = NSMutableAttributedString(attributedString: attributed)
    let s = mutable.string as NSString
    let fullRange = NSRange(location: 0, length: s.length)

    let pattern = "\\{\\{[^{}]+\\}\\}" // same as apply
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return attributed }

    regex.enumerateMatches(in: mutable.string, range: fullRange) { match, _, _ in
        guard let r = match?.range, r.length > 0 else { return }

        // Remove token styling so it doesn't get saved/exported.
        // (Other user-chosen colors elsewhere remain.)
        mutable.removeAttribute(.foregroundColor, range: r)

        // Also remove the bold we apply in the editor for tokens.
        mutable.enumerateAttribute(.font, in: r, options: []) { value, subRange, _ in
            let baseFont = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            let descriptor = baseFont.fontDescriptor
            var traits = descriptor.symbolicTraits
            traits.remove(.traitBold)
            if let newDescriptor = descriptor.withSymbolicTraits(traits) {
                mutable.addAttribute(.font, value: UIFont(descriptor: newDescriptor, size: baseFont.pointSize), range: subRange)
            } else {
                mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: baseFont.pointSize), range: subRange)
            }
        }
    }

    return mutable
}

// MARK: - Attributed text helpers

enum RichTextFormatKind {
    case bold
    case italic
}

struct RichTextFormatting {
    static func toggle(_ kind: RichTextFormatKind, in attributed: NSAttributedString, range: NSRange) -> NSAttributedString {
        let fullRange = NSRange(location: 0, length: attributed.length)
        let mutable = NSMutableAttributedString(attributedString: attributed)

        let targetRange = sanitize(range, within: attributed.length)

        // If selection is empty, toggle typing attributes by inserting a zero-width marker is overkill.
        // MVP behavior: if empty selection, do nothing.
        guard targetRange.length > 0 else { return attributed }

        mutable.enumerateAttribute(.font, in: targetRange, options: []) { value, subRange, _ in
            let baseFont = (value as? UIFont) ?? UIFont.systemFont(ofSize: 16)
            let newFont = apply(kind, to: baseFont)
            mutable.addAttribute(.font, value: newFont, range: subRange)
        }

        // Ensure whole string has a font attribute so HTML export is stable.
        if attributed.attribute(.font, at: 0, effectiveRange: nil) == nil {
            mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: fullRange)
        }

        return mutable
    }

    static func applyColor(_ color: UIColor, in attributed: NSAttributedString, range: NSRange) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let targetRange = sanitize(range, within: attributed.length)
        guard targetRange.length > 0 else { return attributed }
        mutable.addAttribute(.foregroundColor, value: color, range: targetRange)
        return mutable
    }

    private static func apply(_ kind: RichTextFormatKind, to font: UIFont) -> UIFont {
        let descriptor = font.fontDescriptor
        var traits = descriptor.symbolicTraits

        switch kind {
        case .bold:
            if traits.contains(.traitBold) {
                traits.remove(.traitBold)
            } else {
                traits.insert(.traitBold)
            }
        case .italic:
            if traits.contains(.traitItalic) {
                traits.remove(.traitItalic)
            } else {
                traits.insert(.traitItalic)
            }
        }

        if let newDescriptor = descriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: newDescriptor, size: font.pointSize)
        }

        // Fallback
        switch kind {
        case .bold:
            return traits.contains(.traitBold) ? UIFont.boldSystemFont(ofSize: font.pointSize) : UIFont.systemFont(ofSize: font.pointSize)
        case .italic:
            return traits.contains(.traitItalic) ? UIFont.italicSystemFont(ofSize: font.pointSize) : UIFont.systemFont(ofSize: font.pointSize)
        }
    }

    private static func sanitize(_ range: NSRange, within length: Int) -> NSRange {
        let loc = min(max(range.location, 0), length)
        let maxLen = max(0, length - loc)
        let len = min(max(range.length, 0), maxLen)
        return NSRange(location: loc, length: len)
    }
}

extension UIColor {
    /// Supports "#RRGGBB" or "RRGGBB".
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

extension NSAttributedString {
    func toHTML() -> String? {
        guard length > 0 else { return nil }
        do {
            let fullRange = NSRange(location: 0, length: length)
            let data = try data(
                from: fullRange,
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ]
            )
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func fromHTML(_ html: String) -> NSAttributedString {
        guard let data = html.data(using: .utf8) else { return NSAttributedString(string: html) }
        do {
            return try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
        } catch {
            return NSAttributedString(string: html)
        }
    }
}
