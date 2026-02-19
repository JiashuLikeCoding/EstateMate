import SwiftUI

struct CRMBulkEmailComposeView: View {
    struct Recipient: Identifiable, Hashable {
        let id: UUID
        let name: String
        let email: String
    }

    let recipients: [Recipient]
    let skippedNoEmail: [String]

    @Environment(\.dismiss) private var dismiss

    @State private var subject: String = ""
    @State private var bodyText: String = ""

    @State private var isSending = false
    @State private var errorMessage: String?

    @State private var sentOK = false
    @State private var sentCount: Int = 0
    @State private var failed: [(Recipient, String)] = []

    private let gmail = CRMGmailIntegrationService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("群发邮件", subtitle: "将使用当前连接的 Gmail 账号发送")

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("收件人")
                                    .font(.headline)
                                    .foregroundStyle(EMTheme.ink)
                                Spacer()
                                Text("\(recipients.count) 人")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(EMTheme.ink2)
                            }

                            if recipients.isEmpty {
                                Text("没有可发送的邮箱")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(recipients.prefix(3))) { r in
                                        Text("• \(r.name.isEmpty ? r.email : "\(r.name) <\(r.email)>")")
                                            .font(.subheadline)
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                    if recipients.count > 3 {
                                        Text("还有 \(recipients.count - 3) 人…")
                                            .font(.subheadline)
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                }
                            }

                            if !skippedNoEmail.isEmpty {
                                Divider().overlay(EMTheme.line)
                                Text("以下客户没有邮箱，已跳过：")
                                    .font(.footnote)
                                    .foregroundStyle(EMTheme.ink2)
                                ForEach(Array(skippedNoEmail.prefix(3)), id: \.self) { s in
                                    Text("• \(s)")
                                        .font(.footnote)
                                        .foregroundStyle(EMTheme.ink2)
                                }
                                if skippedNoEmail.count > 3 {
                                    Text("还有 \(skippedNoEmail.count - 3) 人…")
                                        .font(.footnote)
                                        .foregroundStyle(EMTheme.ink2)
                                }
                            }
                        }
                    }

                    EMCard {
                        EMTextField(title: "主题", text: $subject, prompt: "例如：感谢来访 + 补充资料")
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("内容")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            TextEditor(text: $bodyText)
                                .frame(minHeight: 180)
                        }
                    }

                    if isSending {
                        EMCard {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("发送中… 已完成 \(sentCount)/\(recipients.count)")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    Button(isSending ? "发送中…" : "发送") {
                        hideKeyboard()
                        Task { await sendAll() }
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isSending || !canSend))
                    .disabled(isSending || !canSend)
                    .alert("发送完成", isPresented: $sentOK) {
                        Button("好的") { dismiss() }
                    } message: {
                        if failed.isEmpty {
                            Text("已发送 \(sentCount) 封")
                        } else {
                            Text("已发送 \(sentCount) 封，失败 \(failed.count) 封（可稍后重试）")
                        }
                    }

                    Button("取消") { dismiss() }
                        .buttonStyle(EMSecondaryButtonStyle())
                        .disabled(isSending)

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("群发")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture { hideKeyboard() }
    }

    private var canSend: Bool {
        !recipients.isEmpty &&
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendAll() async {
        isSending = true
        errorMessage = nil
        failed = []
        sentCount = 0
        defer { isSending = false }

        let s = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = bodyText

        for r in recipients {
            do {
                _ = try await gmail.sendMessage(
                    to: r.email,
                    subject: s,
                    text: b,
                    html: nil,
                    submissionId: "crm_bulk_\(r.id.uuidString)_\(UUID().uuidString)",
                    threadId: nil,
                    inReplyTo: nil,
                    references: nil
                )
                sentCount += 1
            } catch {
                failed.append((r, error.localizedDescription))
            }
        }

        sentOK = true
    }
}
