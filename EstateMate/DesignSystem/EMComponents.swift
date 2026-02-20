//
//  EMComponents.swift
//  EstateMate
//

import SwiftUI

// MARK: - Accent Color (per module)

private struct EMAccentColorKey: EnvironmentKey {
    static let defaultValue: Color = EMTheme.accent
}

extension EnvironmentValues {
    var emAccentColor: Color {
        get { self[EMAccentColorKey.self] }
        set { self[EMAccentColorKey.self] = newValue }
    }
}

extension View {
    func emAccentColor(_ color: Color) -> some View {
        environment(\.emAccentColor, color)
            .tint(color)
    }
}

struct EMScreen<Content: View>: View {
    let title: String?
    let content: Content

    @Environment(\.emAccentColor) private var accent

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Tap the background to dismiss keyboard.
            // Important: don't attach the gesture to the whole container (it would also fire when tapping inside TextField,
            // causing focus to drop immediately and making editing feel "cancelled").
            EMTheme.paper
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }

            content
                .foregroundStyle(EMTheme.ink)
        }
        .tint(accent)
        .navigationTitle(title ?? "")
        .navigationBarTitleDisplayMode(.inline)
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

    /// When provided, the input text will use this color.
    var textColor: Color? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)
            }

            Group {
                if isSecure {
                    SecureField(prompt ?? "", text: text)
                        .focused($isFocused)
                        .font(.callout)
                        .foregroundStyle(textColor ?? EMTheme.ink)
                } else {
                    TextField(prompt ?? "", text: text)
                        .focused($isFocused)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .font(.callout)
                        .foregroundStyle(textColor ?? EMTheme.ink)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            // Make the whole rounded rect tappable; tapping inside the field should keep/focus editing
            // instead of being interpreted as a background tap (which would dismiss the keyboard).
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
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

struct EMEmailField: View {
    let title: String
    var text: Binding<String>
    var prompt: String? = nil

    /// Common domains for quick selection.
    var domains: [String] = ["gmail.com", "icloud.com", "outlook.com", "hotmail.com", "yahoo.com"]
    var defaultDomain: String = "gmail.com"

    @State private var localPart: String = ""
    @State private var selectedDomain: String = "gmail.com"
    @State private var useCustomDomain: Bool = false
    @State private var customDomain: String = ""
    @State private var isExpanded: Bool = false

    private var effectiveDomain: String {
        let d = (useCustomDomain ? customDomain : selectedDomain)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return d
    }

    private var previewEmail: String {
        let local = localPart.trimmingCharacters(in: .whitespacesAndNewlines)
        if local.isEmpty { return "" }
        let d = effectiveDomain
        if d.isEmpty { return local }
        return "\(local)@\(d)"
    }

    private var domainDisplay: String {
        if useCustomDomain {
            let d = customDomain.trimmingCharacters(in: .whitespacesAndNewlines)
            return d.isEmpty ? "自定义" : d
        }
        return selectedDomain
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)
            }

            // Compact: local-part + a domain selector in the same row.
            // Use EMInlineTextField to keep height/padding consistent with other inputs (name/phone/etc.).
            HStack(spacing: 10) {
                EMInlineTextField(text: $localPart, prompt: prompt ?? "邮箱前缀", keyboard: .emailAddress)
                    .onChange(of: localPart) { _, _ in
                        syncToBinding()
                    }

                Text("@")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(EMTheme.ink2)

                if useCustomDomain {
                    EMInlineTextField(text: $customDomain, prompt: "company.com", keyboard: .URL)
                        .onChange(of: customDomain) { _, _ in
                            syncToBinding()
                        }
                        .frame(maxWidth: 170)
                } else {
                    Text(domainDisplay)
                        .font(.callout)
                        .foregroundStyle(EMTheme.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                .fill(EMTheme.paper2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                .stroke(EMTheme.line, lineWidth: 1)
                        )
                }

                Button {
                    hideKeyboard()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(EMTheme.ink2)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                .fill(EMTheme.paper2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                .stroke(EMTheme.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    FlowLayout(maxPerRow: 3, spacing: 8) {
                        ForEach(domains, id: \.self) { domain in
                            Button {
                                useCustomDomain = false
                                selectedDomain = domain
                                syncToBinding()
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    isExpanded = false
                                }
                            } label: {
                                EMChip(text: domain, isOn: (!useCustomDomain && selectedDomain == domain))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            useCustomDomain = true
                            if customDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                customDomain = ""
                            }
                            syncToBinding()
                        } label: {
                            EMChip(text: "自定义", isOn: useCustomDomain)
                        }
                        .buttonStyle(.plain)
                    }

                    if useCustomDomain {
                        EMInlineTextField(text: $customDomain, prompt: "例如：company.com", keyboard: .URL)
                            .onChange(of: customDomain) { _, _ in
                                syncToBinding()
                            }
                    }

                    if !previewEmail.isEmpty {
                        Text("完整邮箱：\(previewEmail)")
                            .font(.footnote)
                            .foregroundStyle(EMTheme.ink2)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .stroke(EMTheme.line, lineWidth: 1)
                )
            }
        }
        .onAppear {
            hydrateFromBindingIfNeeded()
            syncToBinding()
        }
        .onChange(of: text.wrappedValue) { _, newValue in
            // If the binding was reset externally (e.g. after form submission), reflect it in local UI state.
            let raw = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty {
                localPart = ""
                useCustomDomain = false
                customDomain = ""
                selectedDomain = domains.contains(defaultDomain) ? defaultDomain : (domains.first ?? "gmail.com")
                isExpanded = false
                return
            }

            // If the external value differs from what UI would produce, re-hydrate.
            if raw != previewEmail {
                hydrateFromBindingIfNeeded()
            }
        }
    }

    private func hydrateFromBindingIfNeeded() {
        // Parse an existing full email (if any) into local-part + domain selection.
        let raw = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            selectedDomain = domains.contains(defaultDomain) ? defaultDomain : (domains.first ?? "gmail.com")
            return
        }

        guard let at = raw.firstIndex(of: "@") else {
            localPart = raw
            selectedDomain = domains.contains(defaultDomain) ? defaultDomain : (domains.first ?? "gmail.com")
            return
        }

        localPart = String(raw[..<at])
        let domain = String(raw[raw.index(after: at)...]).lowercased()

        if domains.contains(domain) {
            useCustomDomain = false
            selectedDomain = domain
        } else {
            useCustomDomain = true
            customDomain = domain
            selectedDomain = domains.contains(defaultDomain) ? defaultDomain : (domains.first ?? "gmail.com")
        }
    }

    private func syncToBinding() {
        let local = localPart.trimmingCharacters(in: .whitespacesAndNewlines)
        if local.isEmpty {
            text.wrappedValue = ""
            return
        }

        let d = effectiveDomain
        if d.isEmpty {
            // Allow incomplete state; validation can happen at submit.
            text.wrappedValue = local
            return
        }

        text.wrappedValue = "\(local)@\(d)"
    }
}

struct EMTextArea: View {
    let title: String
    var text: Binding<String>
    var prompt: String? = nil
    var minHeight: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)
            }

            ZStack(alignment: .topLeading) {
                if (text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty), let prompt {
                    Text(prompt)
                        .font(.callout)
                        .foregroundStyle(EMTheme.ink2.opacity(0.75))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }

                TextEditor(text: text)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(minHeight: minHeight)
                    .background(Color.clear)
            }
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

struct EMInlineTextField: View {
    var text: Binding<String>
    var prompt: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField(prompt, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
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

struct EMPhoneWithCountryCodeField: View {
    let title: String
    var code: Binding<String>
    var number: Binding<String>
    var prompt: String = "手机号"

    /// Keep this short + opinionated. This is a “quick picker”, not a full country list.
    var commonCodes: [String] = ["+1", "+86", "+44", "+61", "+49", "+81"]
    var defaultCode: String = "+1"
    var allowCustom: Bool = true

    @State private var isExpanded: Bool = false
    @State private var useCustom: Bool = false
    @State private var customCode: String = ""

    @FocusState private var isCustomCodeFocused: Bool

    private var displayCode: String {
        let raw = code.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return defaultCode }
        return raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)
            }

            // Row stays stable; expansion renders BELOW the row (like EMEmailField), so it won’t squeeze the phone input.
            HStack(spacing: 12) {
                Group {
                    if useCustom {
                        HStack(spacing: 8) {
                            TextField("+1", text: $customCode)
                                .keyboardType(.phonePad)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .focused($isCustomCodeFocused)
                                .onChange(of: customCode) { _, _ in
                                    let raw = customCode.trimmingCharacters(in: .whitespacesAndNewlines)
                                    code.wrappedValue = raw
                                }

                            Button {
                                hideKeyboard()
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(EMTheme.ink2)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(width: 86) // keep the phone number field stable
                        .background(
                            RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                .fill(EMTheme.paper2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                .stroke(EMTheme.line, lineWidth: 1)
                        )
                        .accessibilityLabel("区号（自定义）")
                    } else {
                        Button {
                            hideKeyboard()
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(displayCode)
                                    .font(.callout)
                                    .foregroundStyle(EMTheme.ink)
                                    .lineLimit(1)

                                Image(systemName: "chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(EMTheme.ink2)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(width: 86) // keep the phone number field stable
                            .background(
                                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                    .fill(EMTheme.paper2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                                    .stroke(EMTheme.line, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("区号")
                    }
                }

                let digitsOnlyNumber = Binding<String>(
                    get: { number.wrappedValue },
                    set: { newValue in
                        number.wrappedValue = newValue.filter { $0.isNumber }
                    }
                )

                EMInlineTextField(text: digitsOnlyNumber, prompt: prompt, keyboard: .phonePad)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Keep codes in ONE horizontal row (scrollable), so it doesn’t wrap to multiple lines.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonCodes, id: \.self) { c in
                                Button {
                                    useCustom = false
                                    code.wrappedValue = c
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        isExpanded = false
                                    }
                                } label: {
                                    EMChip(text: c, isOn: (!useCustom && code.wrappedValue == c))
                                }
                                .buttonStyle(.plain)
                            }

                            if allowCustom {
                                Button {
                                    useCustom = true
                                    if customCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        customCode = code.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if customCode.isEmpty { customCode = defaultCode }
                                    }
                                    DispatchQueue.main.async {
                                        isCustomCodeFocused = true
                                    }
                                } label: {
                                    EMChip(text: "自定义", isOn: useCustom)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                        .fixedSize(horizontal: true, vertical: false)
                    }

                    if useCustom {
                        EMInlineTextField(text: $customCode, prompt: "+1", keyboard: .phonePad)
                            .onChange(of: customCode) { _, _ in
                                let raw = customCode.trimmingCharacters(in: .whitespacesAndNewlines)
                                code.wrappedValue = raw
                            }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .stroke(EMTheme.line, lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            // Default it once; don’t keep forcing it.
            let raw = code.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty {
                code.wrappedValue = defaultCode
                useCustom = false
                customCode = ""
            } else if commonCodes.contains(raw) {
                useCustom = false
                customCode = ""
            } else {
                useCustom = true
                customCode = raw
            }

            if useCustom {
                DispatchQueue.main.async {
                    isCustomCodeFocused = false
                }
            }
        }
    }
}

struct EMChoiceField: View {
    let title: String
    let placeholder: String
    let options: [String]
    var selection: Binding<String>

    @Environment(\.emAccentColor) private var accent

    @State private var isExpanded = false

    private var displayText: String {
        let v = selection.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? placeholder : v
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)
            }

            VStack(spacing: 0) {
                Button {
                    hideKeyboard()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(displayText)
                            .font(.callout)
                            .foregroundStyle(selection.wrappedValue.isEmpty ? EMTheme.ink2 : EMTheme.ink)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(EMTheme.ink2)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider().overlay(EMTheme.line)

                    VStack(spacing: 0) {
                        // Keep "清除选择" for now; can hide later if you want.
                        Button {
                            selection.wrappedValue = ""
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                Text("清除选择")
                                    .font(.callout)
                                    .foregroundStyle(EMTheme.ink2)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if options.isEmpty {
                            HStack {
                                Text("暂无选项")
                                    .font(.callout)
                                    .foregroundStyle(EMTheme.ink2)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        } else {
                            ForEach(Array(options.enumerated()), id: \.element) { idx, opt in
                                Divider().overlay(EMTheme.line)
                                    .opacity(idx == 0 ? 0 : 1)

                                Button {
                                    selection.wrappedValue = opt
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        isExpanded = false
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(opt)
                                            .font(.callout)
                                            .foregroundStyle(EMTheme.ink)
                                        Spacer(minLength: 0)
                                        Image(systemName: selection.wrappedValue == opt ? "largecircle.fill.circle" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(selection.wrappedValue == opt ? accent : EMTheme.ink2)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
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

struct EMSelectDotsField: View {
    let title: String
    let options: [String]
    var selection: Binding<String>

    @Environment(\.emAccentColor) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(options, id: \.self) { opt in
                    Button {
                        selection.wrappedValue = opt
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selection.wrappedValue == opt ? "circle.inset.filled" : "circle")
                                .font(.title3)
                                .foregroundStyle(selection.wrappedValue == opt ? accent : EMTheme.ink2)

                            Text(opt)
                                .font(.callout)
                                .foregroundStyle(EMTheme.ink)

                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
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

struct EMMultiSelectField: View {
    let title: String
    let options: [String]
    var selection: Binding<Set<String>>
    var style: MultiSelectStyle = .chips

    @Environment(\.emAccentColor) private var accent

    @State private var isExpanded: Bool = false

    private var summaryText: String {
        let selected = Array(selection.wrappedValue).sorted()
        if selected.isEmpty { return "请选择..." }
        if selected.count <= 2 {
            return selected.joined(separator: "、")
        }
        return "已选择 \(selected.count) 项"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(EMTheme.ink2)
            }

            switch style {
            case .chips:
                FlowLayout(maxPerRow: 3, spacing: 8) {
                    ForEach(options, id: \.self) { opt in
                        let isOn = selection.wrappedValue.contains(opt)
                        Button {
                            toggle(opt)
                        } label: {
                            EMChip(text: opt, isOn: isOn)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .fill(EMTheme.paper2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .stroke(EMTheme.line, lineWidth: 1)
                )

            case .checklist:
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element) { idx, opt in
                        Button {
                            toggle(opt)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selection.wrappedValue.contains(opt) ? "checkmark.square.fill" : "square")
                                    .font(.title3)
                                    .foregroundStyle(selection.wrappedValue.contains(opt) ? accent : EMTheme.ink2)

                                Text(opt)
                                    .font(.callout)
                                    .foregroundStyle(EMTheme.ink)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if idx != options.count - 1 {
                            Divider().overlay(EMTheme.line)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .fill(EMTheme.paper2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .stroke(EMTheme.line, lineWidth: 1)
                )

            case .dropdown:
                VStack(spacing: 0) {
                    Button {
                        hideKeyboard()
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(summaryText)
                                .font(.callout)
                                .foregroundStyle(selection.wrappedValue.isEmpty ? EMTheme.ink2 : EMTheme.ink)

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(EMTheme.ink2)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        Divider().overlay(EMTheme.line)

                        VStack(spacing: 0) {
                            ForEach(Array(options.enumerated()), id: \.element) { idx, opt in
                                Button {
                                    toggle(opt)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(opt)
                                            .font(.callout)
                                            .foregroundStyle(EMTheme.ink)

                                        Spacer(minLength: 0)

                                        Image(systemName: selection.wrappedValue.contains(opt) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(selection.wrappedValue.contains(opt) ? accent : EMTheme.ink2)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if idx != options.count - 1 {
                                    Divider().overlay(EMTheme.line)
                                }
                            }
                        }
                    }
                }
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

    private func toggle(_ opt: String) {
        var s = selection.wrappedValue
        if s.contains(opt) {
            s.remove(opt)
        } else {
            s.insert(opt)
        }
        selection.wrappedValue = s
    }
}

struct EMFormBackgroundView: View {
    let background: FormBackground

    @Environment(\.emAccentColor) private var accent

    private let service = DynamicFormService()

    var body: some View {
        ZStack {
            switch background.kind {
            case .builtIn:
                builtInView(key: background.builtInKey ?? "paper")
                    .opacity(background.opacity)

            case .custom:
                if let path = background.storagePath,
                   let url = service.publicURLForFormBackground(path: path) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().fill(EMTheme.paper)
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Rectangle().fill(EMTheme.paper)
                        @unknown default:
                            Rectangle().fill(EMTheme.paper)
                        }
                    }
                    .opacity(background.opacity)
                } else {
                    Rectangle().fill(EMTheme.paper)
                }
            }
        }
        // Ensure background never affects layout size, even when used in small previews.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func builtInView(key: String) -> some View {
        switch key {
        case "grid":
            ZStack {
                LinearGradient(
                    colors: [EMTheme.paper, EMTheme.paper2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // A visible (but still tasteful) grid.
                Canvas { context, size in
                    let step: CGFloat = 24
                    var path = Path()
                    for x in stride(from: 0, through: size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, through: size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(EMTheme.ink2.opacity(0.18)), lineWidth: 0.6)
                }
            }

        case "moss":
            LinearGradient(
                colors: [EMTheme.paper, accent.opacity(0.40), EMTheme.paper2.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )

        default: // paper
            LinearGradient(
                colors: [EMTheme.paper, EMTheme.paper2, EMTheme.paper],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct EMPrimaryButtonStyle: ButtonStyle {
    var disabled: Bool

    @Environment(\.emAccentColor) private var accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .fill(disabled ? Color.gray.opacity(0.35) : accent)
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

/// Red filled button (danger primary).
struct EMDangerFilledButtonStyle: ButtonStyle {
    var disabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .fill(disabled ? Color.gray.opacity(0.35) : Color.red)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct EMGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(EMTheme.ink2)
            .background(Color.clear)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
