//
//  FormBuilderAdaptiveView.swift
//  EstateMate
//
//  iPad: split-view builder (palette + canvas + properties)
//  iPhone: compact builder (segmented sections)
//

import SwiftUI

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
            FormBuilderCompactView()
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
        if trimmed.isEmpty { return UUID().uuidString.lowercased() }
        // basic slug: keep ascii alphanumerics + underscore
        let ascii = trimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        // If non-ascii, just use random key; label is for display anyway.
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
            canvas
                .navigationTitle("表单")
        } detail: {
            properties
                .navigationTitle("属性")
        }
        .task { state.seedIfNeeded() }
        .environmentObject(state)
    }

    private var palette: some View {
        List {
            Section("基础字段") {
                paletteButton("文本输入", systemImage: "text.cursor", type: .text)
                paletteButton("手机号", systemImage: "phone", type: .phone)
                paletteButton("邮箱", systemImage: "envelope", type: .email)
                paletteButton("单选", systemImage: "list.bullet", type: .select)
            }
        }
    }

    private func paletteButton(_ title: String, systemImage: String, type: FormFieldType) -> some View {
        Button {
            state.addField(type: type)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private var canvas: some View {
        FormBuilderCanvasView()
            .environmentObject(state)
    }

    private var properties: some View {
        FormBuilderPropertiesView()
            .environmentObject(state)
    }
}

// MARK: - iPhone Compact View

private struct FormBuilderCompactView: View {
    @StateObject private var state = FormBuilderState()

    enum Tab: String, CaseIterable {
        case palette = "字段"
        case canvas = "画布"
        case properties = "属性"
    }

    @State private var tab: Tab = .canvas

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                Group {
                    switch tab {
                    case .palette:
                        palette
                    case .canvas:
                        FormBuilderCanvasView()
                    case .properties:
                        FormBuilderPropertiesView()
                    }
                }
                .environmentObject(state)
            }
            .navigationTitle("表单设计")
        }
        .task { state.seedIfNeeded() }
    }

    private var palette: some View {
        List {
            Section("基础字段") {
                Button { state.addField(type: .text); tab = .properties } label: { Label("文本输入", systemImage: "text.cursor") }
                Button { state.addField(type: .phone); tab = .properties } label: { Label("手机号", systemImage: "phone") }
                Button { state.addField(type: .email); tab = .properties } label: { Label("邮箱", systemImage: "envelope") }
                Button { state.addField(type: .select); tab = .properties } label: { Label("单选", systemImage: "list.bullet") }
            }
        }
    }
}
