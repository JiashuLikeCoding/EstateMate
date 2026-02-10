import SwiftUI

struct CRMGmailMessageDetailView: View {
    let messageId: String
    let contactEmail: String

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var subject: String = ""
    @State private var from: String = ""
    @State private var to: String = ""
    @State private var date: String = ""
    @State private var bodyText: String = ""
    @State private var threadId: String?
    @State private var messageIdHeader: String?
    @State private var references: String?

    @State private var isReplyPresented = false

    private let gmail = CRMGmailIntegrationService()

    var body: some View {
        EMScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EMSectionHeader("邮件详情", subtitle: "来自 Gmail · 可回复")

                    if let errorMessage {
                        EMCard {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    if isLoading {
                        EMCard {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("正在加载…")
                                    .font(.subheadline)
                                    .foregroundStyle(EMTheme.ink2)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    EMCard {
                        infoRow(label: "主题", value: subject)
                        Divider().overlay(EMTheme.line)
                        infoRow(label: "发件人", value: from)
                        Divider().overlay(EMTheme.line)
                        infoRow(label: "收件人", value: to)
                        Divider().overlay(EMTheme.line)
                        infoRow(label: "日期", value: date)
                    }

                    EMCard {
                        Text(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（无正文）" : bodyText)
                            .font(.body)
                            .foregroundStyle(EMTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("回复") {
                        isReplyPresented = true
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: false))

                    Button("关闭") { dismiss() }
                        .buttonStyle(EMSecondaryButtonStyle())

                    Spacer(minLength: 20)
                }
                .padding(EMTheme.padding)
            }
        }
        .navigationTitle("邮件")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $isReplyPresented) {
            NavigationStack {
                CRMGmailReplyComposeView(
                    contactEmail: contactEmail,
                    defaultSubject: replySubject,
                    threadId: threadId,
                    inReplyTo: messageIdHeader,
                    references: mergedReferences
                )
            }
        }
        .onTapGesture { hideKeyboard() }
    }

    private var replySubject: String {
        let s = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("re:") { return s }
        if s.isEmpty { return "Re:" }
        return "Re: \(s)"
    }

    private var mergedReferences: String? {
        // Append Message-ID to References if present.
        let base = (references ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let mid = (messageIdHeader ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { return mid.isEmpty ? nil : mid }
        if mid.isEmpty { return base }
        if base.contains(mid) { return base }
        return "\(base) \(mid)"
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(EMTheme.ink2)
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value)
                .font(.body)
                .foregroundStyle(EMTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let res = try await gmail.messageGet(messageId: messageId)
            subject = res.subject
            from = res.from
            to = res.to
            date = res.date
            bodyText = res.body.text
            threadId = res.threadId
            messageIdHeader = res.messageId
            references = res.references
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
