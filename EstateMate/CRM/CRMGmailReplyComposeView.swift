import SwiftUI

struct CRMGmailReplyComposeView: View {
    let contactEmail: String
    let defaultSubject: String
    let threadId: String?
    let inReplyTo: String?
    let references: String?

    @Environment(\.dismiss) private var dismiss

    @State private var subject: String
    @State private var bodyText: String = ""

    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var sentOK = false

    private let gmail = CRMGmailIntegrationService()

    init(contactEmail: String, defaultSubject: String, threadId: String?, inReplyTo: String?, references: String?) {
        self.contactEmail = contactEmail
        self.defaultSubject = defaultSubject
        self.threadId = threadId
        self.inReplyTo = inReplyTo
        self.references = references
        _subject = State(initialValue: defaultSubject)
    }

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("回复邮件", subtitle: "将使用当前连接的 Gmail 账号发送")

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    EMCard {
                        EMTextField(title: "收件人", text: .constant(contactEmail), prompt: "")
                            .disabled(true)
                        Divider().overlay(EMTheme.line)
                        EMTextField(title: "主题", text: $subject, prompt: "Re: ...")
                    }

                    EMCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("内容")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(EMTheme.ink2)
                            TextEditor(text: $bodyText)
                                .frame(minHeight: 160)
                        }
                    }

                    Button(isSending ? "发送中…" : "发送") {
                        hideKeyboard()
                        Task { await send() }
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: isSending || !canSend))
                    .disabled(isSending || !canSend)
                    .alert("已发送", isPresented: $sentOK) {
                        Button("好的") { dismiss() }
                    }

                    Button("取消") { dismiss() }
                        .buttonStyle(EMSecondaryButtonStyle())

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("回复")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture { hideKeyboard() }
    }

    private var canSend: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            _ = try await gmail.sendMessage(
                to: contactEmail,
                subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                text: bodyText,
                html: nil,
                submissionId: "crm_reply_\(UUID().uuidString)",
                threadId: threadId,
                inReplyTo: inReplyTo,
                references: references
            )
            sentOK = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
