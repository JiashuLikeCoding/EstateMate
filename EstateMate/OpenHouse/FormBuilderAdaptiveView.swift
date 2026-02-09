//
//  FormBuilderAdaptiveView.swift
//  EstateMate
//
//  iPad: split view (palette grid + canvas + properties)
//  iPhone: canvas with bottom drawer (palette / properties)
//

import SwiftUI
import Combine

struct FormBuilderAdaptiveView: View {
    var body: some View {
        FormBuilderContainerView()
    }
}

private struct FormBuilderContainerView: View {
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        if hSize == .regular {
            FormBuilderSplitView()
        } else {
            FormBuilderDrawerView()
        }
    }
}

// MARK: - Shared builder state

@MainActor
final class FormBuilderState: ObservableObject {
    @Published var formName: String = ""
    @Published var fields: [FormField] = []
    @Published var selectedFieldKey: String? = nil

    /// When adding a new field, we stage it here so user can confirm Add/Cancel.
    @Published var draftField: FormField? = nil

    @Published var errorMessage: String? = nil
    @Published var isSaving: Bool = false

    func seedIfNeeded() {
        // Start empty: user decides what to include.
        guard fields.isEmpty else { return }
        fields = []
    }

    func startDraft(type: FormFieldType) {
        startDraft(presetLabel: nil, presetKey: nil, type: type, required: false)
    }

    func startDraft(presetLabel: String?, presetKey: String?, type: FormFieldType, required: Bool) {
        let baseLabel: String
        switch type {
        case .text: baseLabel = presetLabel ?? "文本"
        case .phone: baseLabel = presetLabel ?? "手机号"
        case .email: baseLabel = presetLabel ?? "邮箱"
        case .select: baseLabel = presetLabel ?? "单选"
        case .name: baseLabel = presetLabel ?? "姓名"
        }

        let label = uniqueLabel(baseLabel)
        let key = {
            if let presetKey, !fields.contains(where: { $0.key == presetKey }) {
                return presetKey
            }
            return makeKey(from: label)
        }()

        let options: [String]? = (type == .select) ? ["选项 1", "选项 2"] : nil

        let (nameFormat, nameKeys): (NameFormat?, [String]?) = {
            guard type == .name else { return (nil, nil) }
            let f: NameFormat = .firstLast
            let keys = makeUniqueNameKeys(for: f)
            return (f, keys)
        }()

        let (phoneFormat, phoneKeys): (PhoneFormat?, [String]?) = {
            guard type == .phone else { return (nil, nil) }
            let f: PhoneFormat = .plain
            let keys = makeUniquePhoneKeys(for: f)
            return (f, keys)
        }()

        draftField = .init(
            key: key,
            label: label,
            type: type,
            required: required,
            options: options,
            textCase: type == .text ? TextCase.none : nil,
            nameFormat: nameFormat,
            nameKeys: nameKeys,
            phoneFormat: phoneFormat,
            phoneKeys: phoneKeys
        )
    }

    private func makeUniqueNameKeys(for format: NameFormat) -> [String] {
        let base: [String]
        switch format {
        case .fullName:
            base = ["full_name"]
        case .firstLast:
            base = ["first_name", "last_name"]
        case .firstMiddleLast:
            base = ["first_name", "middle_name", "last_name"]
        }

        func unique(_ key: String) -> String {
            if !fields.contains(where: { $0.key == key || ($0.nameKeys ?? []).contains(key) }) {
                return key
            }
            var i = 2
            while fields.contains(where: { $0.key == "\(key)_\(i)" || ($0.nameKeys ?? []).contains("\(key)_\(i)") }) {
                i += 1
            }
            return "\(key)_\(i)"
        }

        return base.map(unique)
    }

    private func makeUniquePhoneKeys(for format: PhoneFormat) -> [String] {
        let base: [String]
        switch format {
        case .plain:
            base = ["phone"]
        case .withCountryCode:
            base = ["country_code", "phone_number"]
        }

        func unique(_ key: String) -> String {
            if !fields.contains(where: { $0.key == key || ($0.nameKeys ?? []).contains(key) || ($0.phoneKeys ?? []).contains(key) }) {
                return key
            }
            var i = 2
            while fields.contains(where: { $0.key == "\(key)_\(i)" || ($0.phoneKeys ?? []).contains("\(key)_\(i)") }) {
                i += 1
            }
            return "\(key)_\(i)"
        }

        return base.map(unique)
    }

    func confirmDraft() {
        guard let draftField else { return }
        fields.append(draftField)
        selectedFieldKey = draftField.key
        self.draftField = nil
    }

    func cancelDraft() {
        draftField = nil
    }

    func deleteSelectedIfPossible() {
        guard let key = selectedFieldKey else { return }
        fields.removeAll { $0.key == key }
        selectedFieldKey = nil
    }

    func move(from: IndexSet, to: Int) {
        fields.move(fromOffsets: from, toOffset: to)
    }

    func makeKey(from label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "f_\(UUID().uuidString.prefix(8))" }
        let ascii = trimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        if ascii.unicodeScalars.contains(where: { $0.value > 127 }) {
            return "f_\(UUID().uuidString.prefix(8))"
        }
        return ascii.isEmpty ? "f_\(UUID().uuidString.prefix(8))" : ascii
    }

    private func uniqueLabel(_ base: String) -> String {
        if !fields.contains(where: { $0.label == base }) { return base }
        var i = 2
        while fields.contains(where: { $0.label == "\(base) \(i)" }) { i += 1 }
        return "\(base) \(i)"
    }
}

// MARK: - iPad Split View

private struct FormBuilderSplitView: View {
    @StateObject private var state = FormBuilderState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            palette
                .navigationTitle("字段库")
        } content: {
            EMScreen("表单设计") {
                FormBuilderCanvasView()
                    .environmentObject(state)
            }
        } detail: {
            EMScreen("属性") {
                FormBuilderPropertiesView()
                    .environmentObject(state)
            }
        }
        .task { state.seedIfNeeded() }
        .environmentObject(state)
    }

    private var palette: some View {
        EMScreen("字段库") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("基础字段")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        palettePresetCard(title: "姓名", subtitle: "常用", systemImage: "person", presetKey: "name", type: .name, required: false)
                        paletteCard(title: "文本输入", systemImage: "text.cursor", type: .text)
                        paletteCard(title: "手机号", systemImage: "phone", type: .phone)
                        paletteCard(title: "邮箱", systemImage: "envelope", type: .email)
                        paletteCard(title: "单选", systemImage: "list.bullet", type: .select)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 20)
                }
            }
        }
    }

    private func paletteCard(title: String, systemImage: String, type: FormFieldType) -> some View {
        Button {
            state.startDraft(type: type)
        } label: {
            paletteCardBody(title: title, subtitle: "点击添加", systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func palettePresetCard(title: String, subtitle: String, systemImage: String, presetKey: String, type: FormFieldType, required: Bool) -> some View {
        Button {
            state.startDraft(presetLabel: title, presetKey: presetKey, type: type, required: required)
        } label: {
            paletteCardBody(title: title, subtitle: subtitle, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func paletteCardBody(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(EMTheme.accent)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EMTheme.ink)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(EMTheme.ink2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(12)
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

// MARK: - iPhone Drawer View

private struct FormBuilderDrawerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = FormBuilderState()

    enum SheetMode {
        case palette
        case properties
    }

    @State private var isSheetPresented: Bool = false
    @State private var mode: SheetMode = .palette
    @State private var sheetHeight: CGFloat = 520

    var body: some View {
        NavigationStack {
            EMScreen("表单设计") {
                FormBuilderCanvasView(
                    addFieldAction: {
                        mode = .palette
                        isSheetPresented = true
                    },
                    onSaved: {
                        // After saving, return to OpenHouse.
                        dismiss()
                    }
                )
                .environmentObject(state)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mode = .properties
                        isSheetPresented = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(EMTheme.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(state.selectedFieldKey == nil)
                    .opacity(state.selectedFieldKey == nil ? 0.4 : 1)
                }
            }
            .sheet(isPresented: $isSheetPresented) {
                NavigationStack {
                    Group {
                        switch mode {
                        case .palette:
                            EMScreen("字段库") {
                                paletteList
                                    .environmentObject(state)
                                    .emReadHeight { h in
                                        // Clamp to reasonable range so it doesn't get tiny/huge.
                                        sheetHeight = min(max(h + 80, 360), 720)
                                    }
                            }
                        case .properties:
                            EMScreen("属性") {
                                FormBuilderPropertiesView(
                                    onDone: {
                                        // keep sheet open, go back to palette for continuous adding
                                        mode = .palette
                                    }
                                )
                                .environmentObject(state)
                                .emReadHeight { h in
                                    sheetHeight = min(max(h + 80, 420), 820)
                                }
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(mode == .properties ? "返回" : "关闭") {
                                if mode == .properties {
                                    mode = .palette
                                } else {
                                    isSheetPresented = false
                                }
                            }
                            .foregroundStyle(EMTheme.ink2)
                        }
                    }
                }
                .presentationDetents([.height(sheetHeight), .large])
                .presentationDragIndicator(.visible)
            }
        }
        .task { state.seedIfNeeded() }
    }

    private var paletteList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                EMSectionHeader("字段库", subtitle: "点击添加到表单")

                EMCard {
                    palettePresetRow(title: "姓名", systemImage: "person", presetKey: "name", type: .name, required: false)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "文本输入", systemImage: "text.cursor", type: .text)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "手机号", systemImage: "phone", type: .phone)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "邮箱", systemImage: "envelope", type: .email)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "单选", systemImage: "list.bullet", type: .select)
                }
            }
            .padding(EMTheme.padding)
        }
    }

    private func paletteRow(title: String, systemImage: String, type: FormFieldType) -> some View {
        let added = state.fields.contains(where: { $0.type == type })
        return Button {
            state.startDraft(type: type)
            mode = .properties
            isSheetPresented = true
        } label: {
            paletteRowBody(title: title, systemImage: systemImage, added: added)
        }
        .buttonStyle(.plain)
    }

    private func palettePresetRow(title: String, systemImage: String, presetKey: String, type: FormFieldType, required: Bool) -> some View {
        let added = state.fields.contains(where: { $0.type == type })
        return Button {
            state.startDraft(presetLabel: title, presetKey: presetKey, type: type, required: required)
            mode = .properties
            isSheetPresented = true
        } label: {
            paletteRowBody(title: title, systemImage: systemImage, added: added)
        }
        .buttonStyle(.plain)
    }

    private func paletteRowBody(title: String, systemImage: String, added: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 28)
                .foregroundStyle(EMTheme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(EMTheme.ink)
            Spacer()

            if added {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(EMTheme.accent)
            } else {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(EMTheme.accent)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

}
