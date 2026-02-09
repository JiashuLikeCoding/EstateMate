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

    @Published var errorMessage: String? = nil
    @Published var isSaving: Bool = false

    func seedIfNeeded() {
        guard fields.isEmpty else { return }
        fields = [
            .init(key: "full_name", label: "姓名", type: .text, required: true, options: nil),
            .init(key: "phone", label: "手机号", type: .phone, required: true, options: nil),
            .init(key: "email", label: "邮箱", type: .email, required: false, options: nil)
        ]
    }

    func addField(type: FormFieldType) {
        let baseLabel: String
        switch type {
        case .text: baseLabel = "文本"
        case .phone: baseLabel = "手机号"
        case .email: baseLabel = "邮箱"
        case .select: baseLabel = "单选"
        }

        let label = uniqueLabel(baseLabel)
        let key = makeKey(from: label)
        let options: [String]? = (type == .select) ? ["选项 1", "选项 2"] : nil

        fields.append(.init(key: key, label: label, type: type, required: false, options: options))
        selectedFieldKey = key
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
            state.addField(type: type)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(EMTheme.accent)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EMTheme.ink)

                Text("点击添加")
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
        .buttonStyle(.plain)
    }
}

// MARK: - iPhone Drawer View

private struct FormBuilderDrawerView: View {
    @StateObject private var state = FormBuilderState()

    enum Sheet {
        case palette
        case properties
    }

    @State private var sheet: Sheet? = nil

    var body: some View {
        NavigationStack {
            EMScreen("表单设计") {
                FormBuilderCanvasView()
                    .environmentObject(state)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        sheet = .palette
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("添加字段")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(EMTheme.accent.opacity(0.12))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(EMTheme.accent.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sheet = .properties
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
            .sheet(item: Binding(
                get: {
                    switch sheet {
                    case .palette: return SheetItem(kind: .palette)
                    case .properties: return SheetItem(kind: .properties)
                    case .none: return nil
                    }
                },
                set: { _ in sheet = nil }
            )) { item in
                switch item.kind {
                case .palette:
                    EMScreen("字段库") {
                        paletteList
                            .environmentObject(state)
                    }
                    .presentationDetents([.medium, .large])
                case .properties:
                    EMScreen("属性") {
                        FormBuilderPropertiesView()
                            .environmentObject(state)
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
        .task { state.seedIfNeeded() }
    }

    private var paletteList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                EMSectionHeader("基础字段", subtitle: "点击添加到画布")

                EMCard {
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
        Button {
            state.addField(type: type)
            // After adding, jump straight into detailed settings.
            sheet = nil
            DispatchQueue.main.async {
                sheet = .properties
            }
        } label: {
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
        .buttonStyle(.plain)
    }

    private struct SheetItem: Identifiable {
        enum Kind { case palette, properties }
        let id = UUID()
        let kind: Kind
    }
}
