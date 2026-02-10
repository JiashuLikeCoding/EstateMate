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
    let form: FormRecord?

    init(form: FormRecord? = nil) {
        self.form = form
    }

    var body: some View {
        FormBuilderContainerView(form: form)
    }
}

private struct FormBuilderContainerView: View {
    let form: FormRecord?

    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        // iPad portrait can still be `.regular`, but the available width may be too narrow for a 3-column split.
        // In that case, fall back to the drawer UI so field editing remains accessible.
        GeometryReader { proxy in
            let w = proxy.size.width

            if hSize == .regular {
                // Even on 12.9" iPad (portrait width ~1024), a 3-column split can still clip the detail controls.
                // Use a higher threshold so portrait reliably falls back to the drawer UI.
                if w < 1100 {
                    FormBuilderDrawerView(form: form)
                } else {
                    FormBuilderSplitView(form: form)
                }
            } else {
                FormBuilderDrawerView(form: form)
            }
        }
    }
}


// MARK: - Shared builder state

@MainActor
final class FormBuilderState: ObservableObject {
    @Published var formId: UUID? = nil
    @Published var formName: String = ""
    @Published var fields: [FormField] = []
    @Published var selectedFieldKey: String? = nil

    @Published var presentation: FormPresentation = .init(background: nil)

    /// When adding a new field, we stage it here so user can confirm Add/Cancel.
    /// Also used when updating an existing field type via the palette (confirm Update/Cancel).
    @Published var draftField: FormField? = nil

    /// When not nil, the draft is editing an existing field (key), not adding a new one.
    @Published var editingFieldKey: String? = nil

    @Published var errorMessage: String? = nil
    @Published var isSaving: Bool = false

    func seedIfNeeded() {
        // Start empty: user decides what to include.
        guard fields.isEmpty else { return }
        fields = []
    }

    func load(form: FormRecord) {
        formId = form.id
        formName = form.name
        fields = form.schema.fields
        presentation = form.schema.presentation ?? .init(background: nil)
        selectedFieldKey = fields.first?.key
    }

    func startDraft(type: FormFieldType) {
        startDraft(presetLabel: nil, presetKey: nil, type: type, required: false)
    }

    func cancelDraft() {
        draftField = nil
    }

    func startDraft(presetLabel: String?, presetKey: String?, type: FormFieldType, required: Bool) {
        let baseLabel: String
        switch type {
        case .text: baseLabel = presetLabel ?? "文本"
        case .multilineText: baseLabel = presetLabel ?? "多行文本"
        case .phone: baseLabel = presetLabel ?? "手机号"
        case .email: baseLabel = presetLabel ?? "邮箱"
        case .select: baseLabel = presetLabel ?? "单选"
        case .dropdown: baseLabel = presetLabel ?? "下拉选框"
        case .multiSelect: baseLabel = presetLabel ?? "多选"
        case .checkbox: baseLabel = presetLabel ?? "勾选"
        case .name: baseLabel = presetLabel ?? "姓名"
        case .sectionTitle: baseLabel = presetLabel ?? "大标题"
        case .sectionSubtitle: baseLabel = presetLabel ?? "小标题"
        case .divider: baseLabel = presetLabel ?? "分割线"
        case .splice: baseLabel = presetLabel ?? "拼接"
        }

        let label = uniqueLabel(baseLabel)
        let key = {
            if let presetKey, !fields.contains(where: { $0.key == presetKey }) {
                return presetKey
            }
            return makeKey(from: label)
        }()

        let options: [String]? = (type == .select || type == .dropdown || type == .multiSelect) ? ["选项 1", "选项 2"] : nil

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

        // Decoration defaults
        let decorationFontSize: Double? = {
            switch type {
            case .sectionTitle: return 22
            case .sectionSubtitle: return 16
            default: return nil
            }
        }()

        let dividerDashed: Bool? = (type == .divider) ? false : nil
        let dividerThickness: Double? = (type == .divider) ? 1 : nil

        // Splice has no extra configuration for now.
        let isSplice = type == .splice

        // Divider / splice do not need a label.
        let finalLabel: String = (type == .divider || type == .splice) ? "" : label

        draftField = .init(
            key: key,
            label: finalLabel,
            type: type,
            required: (type == .sectionTitle || type == .sectionSubtitle || type == .divider || isSplice) ? false : required,
            options: options,
            textCase: type == .text ? TextCase.none : nil,
            nameFormat: nameFormat,
            nameKeys: nameKeys,
            phoneFormat: phoneFormat,
            phoneKeys: phoneKeys,
            fontSize: decorationFontSize,
            dividerDashed: dividerDashed,
            dividerThickness: dividerThickness
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

        // Apply change (append or update) into a proposed array first, so we can validate before mutating state.
        var proposed = fields
        if let editingKey = editingFieldKey,
           let idx = proposed.firstIndex(where: { $0.key == editingKey }) {
            proposed[idx] = draftField
        } else {
            proposed.append(draftField)
        }

        if let msg = spliceValidationError(in: proposed) {
            errorMessage = msg
            return
        }

        errorMessage = nil
        fields = proposed
        selectedFieldKey = draftField.key
        self.draftField = nil
        self.editingFieldKey = nil
    }

    func spliceValidationError(in fields: [FormField]) -> String? {
        // Rule recap:
        // - No leading/trailing splice.
        // - No adjacent splice.
        // - Max 4 non-splice fields in a splice-connected chain (i.e. max 3 splices between them).
        guard !fields.isEmpty else { return nil }

        var currentFieldCount = 0
        var currentSpliceCount = 0

        for i in fields.indices {
            let f = fields[i]

            if f.type == .splice {
                if i == fields.startIndex || i == fields.index(before: fields.endIndex) {
                    return "拼接不能放在开头或结尾"
                }

                if fields[i - 1].type == .splice {
                    return "不允许两个拼接挨在一起"
                }

                currentSpliceCount += 1
                if currentSpliceCount > 3 {
                    return "拼接最大支持一行 4 个字段（字段 拼接 字段 拼接 字段 拼接 字段）"
                }
            } else {
                if i > fields.startIndex, fields[i - 1].type == .splice {
                    currentFieldCount += 1
                } else {
                    currentFieldCount = 1
                    currentSpliceCount = 0
                }

                if currentFieldCount > 4 {
                    return "拼接最大支持一行 4 个字段（字段 拼接 字段 拼接 字段 拼接 字段）"
                }
            }
        }

        return nil
    }

    func deleteSelectedIfPossible() {
        guard let key = selectedFieldKey else { return }

        // Important: PropertiesView often holds a Binding into fields[idx].
        // If we mutate the array while that binding is still alive in the current render pass,
        // SwiftUI can crash with an out-of-range access.
        // So we first clear selection/draft to force the editor to leave the indexed binding,
        // then remove the field on the next run loop.
        selectedFieldKey = nil
        draftField = nil
        editingFieldKey = nil

        DispatchQueue.main.async { [weak self] in
            self?.fields.removeAll { $0.key == key }
        }
    }

    /// Update the currently selected field to a new type (used when user is editing an existing field and picks a different type from the palette).
    func updateSelectedFieldType(to newType: FormFieldType, presetLabel: String? = nil) {
        guard let key = selectedFieldKey,
              let idx = fields.firstIndex(where: { $0.key == key })
        else { return }

        var f = fields[idx]
        f.type = newType

        // Keep label unless a preset label was provided.
        if let presetLabel {
            f.label = presetLabel
        }

        // Reset type-specific props.
        f.options = (newType == .select || newType == .dropdown || newType == .multiSelect)
            ? (f.options?.isEmpty == false ? f.options : ["选项 1", "选项 2"])
            : nil
        f.textCase = (newType == .text) ? (f.textCase ?? TextCase.none) : nil

        if newType == .name {
            let format: NameFormat = f.nameFormat ?? .firstLast
            f.nameFormat = format
            f.nameKeys = makeUniqueNameKeys(for: format)
        } else {
            f.nameFormat = nil
            f.nameKeys = nil
        }

        if newType == .phone {
            let format: PhoneFormat = f.phoneFormat ?? .plain
            f.phoneFormat = format
            f.phoneKeys = makeUniquePhoneKeys(for: format)
        } else {
            f.phoneFormat = nil
            f.phoneKeys = nil
        }

        // Stage as a draft update so UI can show "更新字段" instead of delete.
        editingFieldKey = key
        draftField = f
    }

    func move(from: IndexSet, to: Int) {
        var proposed = fields
        proposed.move(fromOffsets: from, toOffset: to)

        if let msg = spliceValidationError(in: proposed) {
            errorMessage = msg
            return
        }

        errorMessage = nil
        fields = proposed
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
    let form: FormRecord?
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
        .task {
            if let form {
                state.load(form: form)
            } else {
                state.seedIfNeeded()
            }
        }
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
                        paletteCard(title: "多行文本", systemImage: "text.alignleft", type: .multilineText)
                        paletteCard(title: "手机号", systemImage: "phone", type: .phone)
                        paletteCard(title: "邮箱", systemImage: "envelope", type: .email)
                        paletteCard(title: "单选", systemImage: "list.bullet", type: .select)
                        paletteCard(title: "下拉选框", systemImage: "chevron.down.square", type: .dropdown)
                        paletteCard(title: "多选", systemImage: "checklist", type: .multiSelect)
                        paletteCard(title: "勾选", systemImage: "checkmark.square", type: .checkbox)

                        paletteCard(title: "大标题", systemImage: "textformat.size.larger", type: .sectionTitle)
                        paletteCard(title: "小标题", systemImage: "textformat.size.smaller", type: .sectionSubtitle)
                        paletteCard(title: "分割线", systemImage: "minus", type: .divider)
                        paletteCard(title: "拼接", systemImage: "rectangle.split.2x1", type: .splice)
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
    let form: FormRecord?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @StateObject private var state = FormBuilderState()

    enum SheetMode {
        case palette
        case properties
    }

    @State private var isSheetPresented: Bool = false
    @State private var mode: SheetMode = .palette
    @State private var sheetHeight: CGFloat = 520

    var body: some View {
        let isIPadLike = (hSize == .regular)

        // Use full-screen cover on iPad (regular size class).
        // A regular `.sheet` can appear as a centered card and feel "broken" for a palette-like workflow.
        let ipadPresented = Binding<Bool>(
            get: { isIPadLike && isSheetPresented },
            set: { isSheetPresented = $0 }
        )
        let phonePresented = Binding<Bool>(
            get: { !isIPadLike && isSheetPresented },
            set: { isSheetPresented = $0 }
        )

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
                    },
                    onEditFieldRequested: {
                        // Tapping a field in preview/list should jump to properties.
                        mode = .properties
                        isSheetPresented = true
                    }
                )
                .environmentObject(state)
            }
        }
        .fullScreenCover(isPresented: ipadPresented) {
            modalContent(showCloseButton: true)
        }
        .sheet(isPresented: phonePresented) {
            modalContent(showCloseButton: false)
                .presentationDetents([.height(sheetHeight), .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            if let form {
                state.load(form: form)
            } else {
                state.seedIfNeeded()
            }
        }
    }

    private func modalContent(showCloseButton: Bool) -> some View {
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
                            },
                            onDeleteClose: {
                                isSheetPresented = false
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
                if showCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("关闭") {
                            isSheetPresented = false
                        }
                    }
                }
            }
        }
    }

    private var paletteList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                EMCard {
                    palettePresetRow(title: "姓名", systemImage: "person", presetKey: "name", type: .name, required: false)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "文本输入", systemImage: "text.cursor", type: .text)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "多行文本", systemImage: "text.alignleft", type: .multilineText)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "手机号", systemImage: "phone", type: .phone)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "邮箱", systemImage: "envelope", type: .email)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "单选", systemImage: "list.bullet", type: .select)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "下拉选框", systemImage: "chevron.down.square", type: .dropdown)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "多选", systemImage: "checklist", type: .multiSelect)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "勾选", systemImage: "checkmark.square", type: .checkbox)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "大标题", systemImage: "textformat.size.larger", type: .sectionTitle)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "小标题", systemImage: "textformat.size.smaller", type: .sectionSubtitle)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "分割线", systemImage: "minus", type: .divider)
                    Divider().overlay(EMTheme.line)
                    paletteRow(title: "拼接", systemImage: "rectangle.split.2x1", type: .splice)
                }

                Button {
                    isSheetPresented = false
                } label: {
                    Text("取消")
                }
                .buttonStyle(EMSecondaryButtonStyle())
            }
            .padding(EMTheme.padding)
        }
    }

    private func paletteRow(title: String, systemImage: String, type: FormFieldType) -> some View {
        return Button {
            state.startDraft(type: type)
            mode = .properties
            isSheetPresented = true
        } label: {
            paletteRowBody(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func palettePresetRow(title: String, systemImage: String, presetKey: String, type: FormFieldType, required: Bool) -> some View {
        return Button {
            state.startDraft(presetLabel: title, presetKey: presetKey, type: type, required: required)
            mode = .properties
            isSheetPresented = true
        } label: {
            paletteRowBody(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func paletteRowBody(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 28)
                .foregroundStyle(EMTheme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(EMTheme.ink)
            Spacer()

            Image(systemName: "plus.circle.fill")
                .foregroundStyle(EMTheme.accent)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

}
