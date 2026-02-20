//
//  FormBuilderCanvasView.swift
//  EstateMate
//

import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

struct FormBuilderCanvasView: View {
    private enum GroupPosition {
        case none
        case start
        case middle
        case end
    }

    private struct Grouping {
        var ids: [Int?] = []
        var counts: [Int: Int] = [:]

        func isGrouped(at index: Int) -> Bool {
            guard ids.indices.contains(index), let gid = ids[index] else { return false }
            return (counts[gid] ?? 0) > 1
        }

        func position(at index: Int) -> GroupPosition {
            guard isGrouped(at: index), let gid = ids[safe: index] else { return .none }

            let prevSame: Bool = {
                let j = index - 1
                guard ids.indices.contains(j) else { return false }
                return ids[j] == gid
            }()

            let nextSame: Bool = {
                let j = index + 1
                guard ids.indices.contains(j) else { return false }
                return ids[j] == gid
            }()

            switch (prevSame, nextSame) {
            case (false, false): return .none
            case (false, true): return .start
            case (true, true): return .middle
            case (true, false): return .end
            }
        }
    }

    private struct GroupOutlineShape: Shape {
        var position: GroupPosition
        var cornerRadius: CGFloat

        func path(in rect: CGRect) -> Path {
            var p = Path()
            let r = min(cornerRadius, min(rect.width, rect.height) / 2)

            // Draw only the edges needed so multiple rows visually form one dashed box.
            switch position {
            case .none:
                return p

            case .start:
                // Top + sides (rounded top corners). No bottom edge.
                p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
                p.addArc(
                    center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                    radius: r,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false
                )
                p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
                p.addArc(
                    center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                    radius: r,
                    startAngle: .degrees(270),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

            case .middle:
                // Sides only.
                p.move(to: CGPoint(x: rect.minX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

            case .end:
                // Bottom + sides (rounded bottom corners). No top edge.
                p.move(to: CGPoint(x: rect.minX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
                p.addArc(
                    center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                    radius: r,
                    startAngle: .degrees(180),
                    endAngle: .degrees(90),
                    clockwise: true
                )
                p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
                p.addArc(
                    center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                    radius: r,
                    startAngle: .degrees(90),
                    endAngle: .degrees(0),
                    clockwise: true
                )
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            }

            return p
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: FormBuilderState
    private let service = DynamicFormService()

    @State private var draggingField: FormField? = nil

    /// If provided, shows a plus button attached to the "表单" card (right side).
    var addFieldAction: (() -> Void)? = nil

    /// Called after a successful save.
    var onSaved: (() -> Void)? = nil

    /// If provided, tapping a field (in list or preview) will request opening the editor UI (iPhone sheet).
    var onEditFieldRequested: (() -> Void)? = nil

    @State private var showSavedAlert: Bool = false
    @State private var showPreviewSheet: Bool = false

    @State private var showArchiveConfirm: Bool = false
    @State private var isArchiving: Bool = false

    @State private var showBackgroundSheet: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var pickedPhotoItem: PhotosPickerItem? = nil
    @State private var showCamera: Bool = false

    private var grouping: Grouping {
        // Grouping rule: a `.splice` connects the closest non-splice field above it with the closest non-splice field below it.
        // We assign the same group id to all fields (and splice rows) in the connected chain.
        var ids: [Int?] = Array(repeating: nil, count: state.fields.count)
        var nextGroupId = 0

        var lastNonSpliceIndex: Int? = nil

        for i in state.fields.indices {
            let f = state.fields[i]
            if f.type == .splice {
                // Splice belongs to the current chain (if any) for tint consistency.
                if let j = lastNonSpliceIndex {
                    ids[i] = ids[j]
                }
                continue
            }

            // If the previous item is a splice, continue the chain.
            if i > 0, state.fields[i - 1].type == .splice, let j = lastNonSpliceIndex {
                ids[i] = ids[j]
            } else {
                ids[i] = nextGroupId
                nextGroupId += 1
            }

            lastNonSpliceIndex = i
        }

        // Count how many non-splice fields each group contains.
        var counts: [Int: Int] = [:]
        for (i, gid) in ids.enumerated() {
            guard let gid else { continue }
            if state.fields[i].type != .splice {
                counts[gid, default: 0] += 1
            }
        }

        // Apply the group count to splice rows too (so they tint only when there's actually a group).
        for (i, gid) in ids.enumerated() {
            guard let gid else { continue }
            if state.fields[i].type == .splice, (counts[gid] ?? 0) <= 1 {
                ids[i] = nil
            }
        }

        return Grouping(ids: ids, counts: counts)
    }

    var body: some View {
        ZStack {
            if let bg = state.presentation.background {
                EMFormBackgroundView(background: bg)
                    .ignoresSafeArea()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let msg = state.errorMessage {
                        Text(msg)
                            .font(.callout)
                            .foregroundStyle(messageColor(for: msg))
                    }

                EMCard {
                    Text("表单信息")
                        .font(.headline)

                    EMTextField(title: "表单名称", text: $state.formName)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("背景图片")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(EMTheme.ink2)

                        Button {
                            hideKeyboard()
                            showBackgroundSheet = true
                        } label: {
                            HStack(spacing: 10) {
                                Text(backgroundSummary)
                                    .font(.callout)
                                    .foregroundStyle(EMTheme.ink)

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(EMTheme.ink2)
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
                        .buttonStyle(.plain)

                        if state.presentation.background != nil {
                            HStack(spacing: 12) {
                                Text("透明度")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)

                                Slider(
                                    value: Binding(
                                        get: { state.presentation.background?.opacity ?? 0.65 },
                                        set: { v in
                                            if state.presentation.background == nil {
                                                state.presentation.background = .default
                                            }
                                            state.presentation.background?.opacity = v
                                        }
                                    ),
                                    in: 0...1
                                )
                            }
                        }
                    }
                }

                EMCard {
                    HStack(alignment: .center, spacing: 12) {
                        Text("表单")
                            .font(.headline)

                        Spacer()

                        Text("长按拖动排序")
                            .font(.caption)
                            .foregroundStyle(EMTheme.ink2)

                        if let addFieldAction {
                            Button(action: addFieldAction) {
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(EMTheme.accent))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("添加字段")
                        }
                    }

                    if state.fields.isEmpty {
                        Text("从字段库添加字段")
                            .foregroundStyle(EMTheme.ink2)
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(state.fields.enumerated()), id: \ .element.id) { idx, f in
                            fieldRow(
                                field: f,
                                isGrouped: grouping.isGrouped(at: idx),
                                groupPosition: grouping.position(at: idx)
                            )
                            .contentShape(Rectangle())
                            // Single tap = select insertion anchor
                            // Double tap = edit field
                            .gesture(
                                ExclusiveGesture(
                                    TapGesture(count: 2),
                                    TapGesture(count: 1)
                                )
                                .onEnded { value in
                                    switch value {
                                    case .first:
                                        state.selectedFieldKey = f.key
                                        onEditFieldRequested?()
                                    case .second:
                                        markInsertionAnchor(key: f.key)
                                    }
                                }
                            )
                            .onDrop(
                                of: [.text],
                                delegate: FieldDropDelegate(
                                    field: f,
                                    fields: $state.fields,
                                    dragging: $draggingField,
                                    errorMessage: Binding(
                                        get: { state.errorMessage },
                                        set: { state.errorMessage = $0 }
                                    ),
                                    validate: { state.spliceValidationError(in: $0) }
                                )
                            )
                        }
                    }
                    .padding(.top, 6)
                }


                Button {
                    hideKeyboard()
                    showPreviewSheet = true
                } label: {
                    Text("预览表单")
                }
                .buttonStyle(EMSecondaryButtonStyle())
                .disabled(state.fields.isEmpty)
                .opacity(state.fields.isEmpty ? 0.45 : 1)

                if state.isArchived {
                    Text("该表单已归档：目前为只读状态。")
                        .font(.footnote)
                        .foregroundStyle(EMTheme.ink2)
                }

                Button(state.isSaving ? "保存中..." : "保存表单") {
                    Task { await save() }
                }
                .buttonStyle(EMPrimaryButtonStyle(disabled: state.isSaving || state.formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isArchived))
                .disabled(state.isSaving || state.formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isArchived)
                .alert("已保存", isPresented: $showSavedAlert) {
                    Button("好的") {
                        if let onSaved {
                            onSaved()
                        } else {
                            dismiss()
                        }
                    }
                } message: {
                    Text("表单已保存")
                }

                archiveSection

                Text("提示：点右侧“＋”添加字段；单击字段选中；双击编辑；长按右侧拖动把手调整顺序")
                    .font(.footnote)
                    .foregroundStyle(EMTheme.ink2)

                // Extra bottom space so the last field row is not stuck under the bottom area (safe area / buttons),
                // especially on iPad portrait where available height is tighter.
                Spacer(minLength: 140)
            }
            .padding(EMTheme.padding)
            }
        }
        .fullScreenCover(isPresented: $showPreviewSheet) {
            NavigationStack {
                FormPreviewView(
                    formName: state.formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "预览" : state.formName,
                    fields: state.fields,
                    presentation: state.presentation
                )
            }
        }
        .sheet(isPresented: $showBackgroundSheet) {
            NavigationStack {
                FormBackgroundPickerSheet(
                    formId: state.formId,
                    background: Binding(
                        get: { state.presentation.background },
                        set: { state.presentation.background = $0 }
                    ),
                    onPickPhoto: {
                        showBackgroundSheet = false
                        showPhotoPicker = true
                    },
                    onPickCamera: {
                        showBackgroundSheet = false
                        showCamera = true
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedPhotoItem, matching: .images)
        .onChange(of: pickedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task { await handlePickedPhoto(item) }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                guard let image else { return }
                Task { await handlePickedUIImage(image) }
            }
        }
    }

    private var archiveSection: some View {
        Group {
            if state.formId != nil {
                Divider().overlay(EMTheme.line)

                Group {
                    if state.isArchived {
                        Button {
                            showArchiveConfirm = true
                        } label: {
                            Text(isArchiving ? "处理中..." : "取消归档")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                    } else {
                        Button {
                            showArchiveConfirm = true
                        } label: {
                            Text(isArchiving ? "处理中..." : "归档表单")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(EMDangerFilledButtonStyle())
                    }
                }
                .disabled(isArchiving)
                .confirmationDialog(
                    state.isArchived ? "取消归档表单？" : "归档表单？",
                    isPresented: $showArchiveConfirm,
                    titleVisibility: .visible
                ) {
                    if state.isArchived {
                        Button("取消归档") {
                            Task { await toggleArchive(isArchived: false) }
                        }
                    } else {
                        Button("归档表单", role: .destructive) {
                            Task { await toggleArchive(isArchived: true) }
                        }
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text(state.isArchived ? "取消归档后可以继续编辑。" : "归档后表单将变为只读，并在列表里默认隐藏。")
                }
            }
        }
    }

    private func toggleArchive(isArchived: Bool) async {
        guard let id = state.formId else { return }
        guard isArchiving == false else { return }

        isArchiving = true
        defer { isArchiving = false }

        do {
            try await service.archiveForm(id: id, isArchived: isArchived)
            state.isArchived = isArchived
            state.errorMessage = nil
        } catch {
            let msg = error.localizedDescription
            if msg.lowercased().contains("is_archived") {
                state.errorMessage = "需要先执行一次数据库迁移：为 forms 增加 is_archived 字段（用于归档）"
            } else {
                state.errorMessage = msg
            }
        }
    }

    private func fieldRow(field f: FormField, isGrouped: Bool, groupPosition: GroupPosition) -> some View {
        let isSplice = (f.type == .splice)
        let isDivider = (f.type == .divider)
        let isSelected = (state.selectedFieldKey == f.key)

        // Option B: when fields are connected by `.splice`, show them as a visually unified module.
        let groupTint = isGrouped ? EMTheme.accent.opacity(0.06) : .clear
        let groupStroke = EMTheme.accent.opacity(0.72)

        // Insertion anchor highlight (more obvious than a 1px stroke)
        let selectedTint = isSelected ? EMTheme.accent.opacity(0.10) : .clear
        let selectedStroke = isSelected ? EMTheme.accent.opacity(0.90) : EMTheme.line
        let selectedLineWidth: CGFloat = isSelected ? 2 : 1

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                switch f.type {
                case .divider:
                    HStack(spacing: 10) {
                        Image(systemName: "line.horizontal.3")
                            .foregroundStyle(EMTheme.ink2)

                        Text("分割线")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(EMTheme.ink)

                        Spacer(minLength: 0)
                    }

                case .splice:
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.split.2x1")
                            .foregroundStyle(EMTheme.ink2)

                        Text("拼接")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(EMTheme.ink)

                        Spacer(minLength: 0)
                    }

                default:
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(f.label)
                            .font(.callout)
                            .foregroundStyle(EMTheme.ink)
                            .frame(width: 86, alignment: .leading)

                        Spacer(minLength: 0)
                    }
                }

                summaryView(f)
                    .font(.caption)

                if let desc = visibilityRelationshipLine(for: f) {
                    Text(desc)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(EMTheme.accent)
                }

                if let desc = visibilityControlsLine(for: f) {
                    Text(desc)
                        .font(.caption2)
                        .foregroundStyle(EMTheme.ink2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EMTheme.ink2)
                .padding(.leading, 6)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onDrag {
                    draggingField = f
                    return NSItemProvider(object: f.key as NSString)
                }
                .accessibilityLabel("拖动排序")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isSplice ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                .fill(EMTheme.paper2)
                .overlay(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .fill(groupTint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                        .fill(selectedTint)
                )
        )
        .overlay(
            ZStack {
                if groupPosition != .none {
                    GroupOutlineShape(position: groupPosition, cornerRadius: EMTheme.radiusSmall + 2)
                        .stroke(
                            groupStroke,
                            style: StrokeStyle(lineWidth: 1.2, dash: [6, 4])
                        )
                        // Let the dashed group outline sit a bit outside the card for clearer grouping.
                        .padding(-4)
                }

                RoundedRectangle(cornerRadius: EMTheme.radiusSmall, style: .continuous)
                    .strokeBorder(
                        selectedStroke,
                        style: StrokeStyle(
                            lineWidth: selectedLineWidth,
                            dash: (isSplice || isDivider) ? [6, 4] : []
                        )
                    )
            }
        )
        .overlay(alignment: .topTrailing) {
            // "Double-tap to edit" hint should not cover the field title.
            if isSelected {
                Text("双击编辑")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(EMTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(EMTheme.accent.opacity(0.10))
                    )
                    // Keep away from the drag handle area.
                    .padding(.trailing, 44)
                    .padding(.top, 8)
            }
        }
        .contentShape(Rectangle())
    }

    private func messageColor(for msg: String) -> Color {
        // We reuse `state.errorMessage` for both errors and short-lived UX hints.
        // Only true errors should be red; hints/normalization notices should be neutral.
        let isHint = msg.hasPrefix("已选中")
            || msg.hasPrefix("已将拼接放到可生效的位置")
            || msg.hasPrefix("已自动修复表单中的拼接结构")

        return isHint ? EMTheme.ink2 : .red
    }

    // Intentionally no placeholder preview in the builder list (keeps the canvas clean).

    private struct FieldDropDelegate: DropDelegate {
        let field: FormField
        @Binding var fields: [FormField]
        @Binding var dragging: FormField?
        @Binding var errorMessage: String?
        let validate: ([FormField]) -> String?

        func dropEntered(info: DropInfo) {
            guard let dragging, dragging.key != field.key,
                  let fromIndex = fields.firstIndex(where: { $0.key == dragging.key }),
                  let toIndex = fields.firstIndex(where: { $0.key == field.key })
            else { return }

            var proposed = fields
            proposed.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)

            if let msg = validate(proposed) {
                errorMessage = msg
                return
            }

            errorMessage = nil
            withAnimation(.snappy) {
                fields = proposed
            }
        }

        func performDrop(info: DropInfo) -> Bool {
            dragging = nil
            return true
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }
    }

    private func markInsertionAnchor(key: String) {
        // Selection should feel instant and never shift the scroll position.
        // Avoid updating the top message here (it can reflow the layout and cause a perceived "jump").
        state.selectedFieldKey = key
    }

    private func titleForKey(_ key: String) -> String {
        if let f = state.fields.first(where: { $0.key == key }) {
            let t = f.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? key : t
        }
        return key
    }

    private func visibilityRelationshipLine(for f: FormField) -> String? {
        // Only show for real input fields.
        switch f.type {
        case .sectionTitle, .sectionSubtitle, .divider, .splice:
            return nil
        default:
            break
        }

        guard let rule = f.visibleWhen else { return nil }
        let triggerTitle = titleForKey(rule.dependsOnKey)
        let opTitle = rule.op.title
        let value = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.isEmpty {
            return "条件显示：当 \(triggerTitle) \(opTitle)（未选择）"
        }
        return "条件显示：当 \(triggerTitle) \(opTitle) \(value)"
    }

    private func visibilityControlsLine(for f: FormField) -> String? {
        // If this field is a trigger for other fields, show a lightweight hint.
        let dependents = state.fields.filter { other in
            other.key != f.key && (other.visibleWhen?.dependsOnKey == f.key)
        }
        guard dependents.isEmpty == false else { return nil }

        let names = dependents
            .compactMap { $0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? $0.key : $0.label }

        if names.count <= 2 {
            return "影响：\(names.joined(separator: "、"))"
        }
        return "影响：\(names.prefix(2).joined(separator: "、")) 等 \(names.count) 项"
    }

    private func summaryTypeTitle(_ f: FormField) -> String {
        switch f.type {
        case .name: "姓名"
        case .text: "文本"
        case .multilineText: "多行文本"
        case .phone: "手机号"
        case .email: "邮箱"
        case .select: "单选"
        case .dropdown: "下拉选框"
        case .multiSelect:
            switch f.multiSelectStyle ?? .chips {
            case .chips: "多选（Chips）"
            case .checklist: "多选（列表）"
            case .dropdown: "多选（下拉）"
            }
        case .checkbox: "勾选（Checkbox）"
        case .date: "日期"
        case .time: "时间"
        case .address: "地址"
        case .sectionTitle: "大标题"
        case .sectionSubtitle: "小标题"
        case .divider: "分割线"
        case .splice: "拼接"
        }
    }

    @ViewBuilder
    private func summaryView(_ f: FormField) -> some View {
        let type = summaryTypeTitle(f)

        // Decoration fields are display-only.
        if f.type == .sectionTitle || f.type == .sectionSubtitle || f.type == .divider || f.type == .splice {
            Text("类型：\(type)")
                .foregroundStyle(EMTheme.ink2)
        } else {
            HStack(spacing: 0) {
                Text("类型：\(type)  ·  ")
                    .foregroundStyle(EMTheme.ink2)

                if f.required {
                    Text("必填")
                        .foregroundStyle(EMTheme.accent)
                        .fontWeight(.semibold)
                } else {
                    Text("选填")
                        .foregroundStyle(EMTheme.ink2)
                }
            }
        }
    }

    private var backgroundSummary: String {
        guard let bg = state.presentation.background else { return "无" }
        switch bg.kind {
        case .builtIn:
            switch bg.builtInKey ?? "paper" {
            case "paper": return "内置：纸感"
            case "grid": return "内置：淡网格"
            case "moss": return "内置：苔绿"
            default: return "内置"
            }
        case .custom:
            return "自定义图片"
        }
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        do {
            // Prefer Data to avoid temp file juggling.
            guard let data = try await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data)
            else {
                throw NSError(domain: "PhotoPicker", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取图片"])
            }
            await handlePickedUIImage(img)
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func handlePickedUIImage(_ image: UIImage) async {
        guard let formId = state.formId else {
            state.errorMessage = "请先保存表单，然后再设置自定义背景图片"
            return
        }

        do {
            let path = try await service.uploadFormBackground(formId: formId, image: image)
            let opacity = max(state.presentation.background?.opacity ?? 0.22, 0.22)
            state.presentation.background = .init(kind: .custom, builtInKey: nil, storagePath: path, opacity: opacity)
            state.errorMessage = nil
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }



    private func save() async {
        state.isSaving = true
        defer { state.isSaving = false }

        do {
            try await state.save(using: service)
            showSavedAlert = true
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
