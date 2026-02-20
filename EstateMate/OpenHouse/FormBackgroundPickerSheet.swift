import Foundation
import SwiftUI

struct FormBackgroundPickerSheet: View {
    let formId: UUID?

    @Binding var background: FormBackground?

    var onPickPhoto: () -> Void
    var onPickCamera: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EMScreen("背景图片") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("选择背景")
                                .font(.headline)

                            Text("提示：背景会显示在访客填写表单页和预览页。")
                                .font(.footnote)
                                .foregroundStyle(EMTheme.ink2)
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 12) {
                            backgroundOption(
                                title: "无背景",
                                subtitle: "使用默认纯色背景",
                                isSelected: background == nil,
                                preview: AnyView(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(EMTheme.paper)
                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(EMTheme.line, lineWidth: 1))
                                ),
                                onTap: {
                                    background = nil
                                    dismiss()
                                }
                            )

                            Divider().overlay(EMTheme.line)

                            builtInOption(key: "paper", title: "纸感")
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("自定义图片")
                                .font(.headline)

                            Text(formId == nil ? "请先保存表单，然后再设置自定义背景图片。" : "从相册选择或拍照上传。")
                                .font(.footnote)
                                .foregroundStyle(formId == nil ? .red : EMTheme.ink2)

                            HStack(spacing: 12) {
                                Button("从相册选择") {
                                    onPickPhoto()
                                }
                                .buttonStyle(EMSecondaryButtonStyle())
                                .disabled(formId == nil)
                                .opacity(formId == nil ? 0.5 : 1)

                                Button("拍照") {
                                    onPickCamera()
                                }
                                .buttonStyle(EMSecondaryButtonStyle())
                                .disabled(formId == nil)
                                .opacity(formId == nil ? 0.5 : 1)
                            }

                            if let bg = background, bg.kind == .custom {
                                Text("当前：自定义图片")
                                    .font(.footnote)
                                    .foregroundStyle(EMTheme.ink2)
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回") { dismiss() }
            }
        }
    }

    private func builtInOption(key: String, title: String) -> some View {
        let isSelected = (background?.kind == .builtIn && background?.builtInKey == key)
        let opacity = background?.opacity ?? 0.65

        return backgroundOption(
            title: "内置：\(title)",
            subtitle: nil,
            isSelected: isSelected,
            preview: AnyView(
                ZStack {
                    EMFormBackgroundView(background: .init(kind: .builtIn, builtInKey: key, storagePath: nil, opacity: 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(EMTheme.line, lineWidth: 1))

                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(EMTheme.accent, lineWidth: 2)
                    }
                }
            ),
            onTap: {
                background = .init(kind: .builtIn, builtInKey: key, storagePath: nil, opacity: opacity)
                dismiss()
            }
        )
    }

    private func backgroundOption(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        preview: AnyView,
        onTap: @escaping () -> Void
    ) -> some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                preview
                    .frame(width: 84, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(EMTheme.ink)

                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(EMTheme.ink2)
                    }
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(EMTheme.accent)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(EMTheme.line)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
