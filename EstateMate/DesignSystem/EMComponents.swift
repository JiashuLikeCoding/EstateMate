//
//  EMComponents.swift
//  EstateMate
//

import SwiftUI

struct EMScreen<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack {
            EMTheme.paper.ignoresSafeArea()
            content
                .foregroundStyle(EMTheme.ink)
        }
        .tint(EMTheme.accent)
        .navigationTitle(title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        // Dismiss keyboard when tapping anywhere.
        .simultaneousGesture(
            TapGesture().onEnded {
                hideKeyboard()
            }
        )
    }
}

// MARK: - Keyboard

@MainActor
func hideKeyboard() {
#if canImport(UIKit)
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
#endif
}

struct EMCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: EMTheme.radius, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EMTheme.radius, style: .continuous)
                .stroke(EMTheme.line, lineWidth: 1)
        )
    }
}

struct EMSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(EMTheme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(EMTheme.ink2)
            }
        }
    }
}

struct EMTextField: View {
    let title: String
    var text: Binding<String>
    var prompt: String? = nil
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(EMTheme.ink2)

            Group {
                if isSecure {
                    SecureField(prompt ?? "", text: text)
                } else {
                    TextField(prompt ?? "", text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .fill(EMTheme.paper2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .stroke(EMTheme.line, lineWidth: 1)
            )
        }
    }
}

struct EMPrimaryButtonStyle: ButtonStyle {
    var disabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .fill(disabled ? Color.gray.opacity(0.35) : EMTheme.accent)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct EMSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(EMTheme.ink)
            .background(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .stroke(EMTheme.line, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct EMDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.red)
            .background(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .stroke(Color.red.opacity(0.25), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}
