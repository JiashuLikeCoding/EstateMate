import Foundation
import Supabase

final class EmailTemplateAIFormatService {
    struct Response: Decodable {
        let subject: String
        let body_html: String
        let notes: String?
    }

    func format(workspace: EstateMateWorkspaceKind, subject: String, body: String) async throws -> Response {
        let client = SupabaseClientProvider.client

        let payload: [String: Any] = [
            "workspace": workspace.rawValue,
            "subject": subject,
            "body": body,
            "language": "zh",
            "tone": "japanese_minimal"
        ]

        do {
            return try await client.functions.invoke(
                "email_template_format_ai",
                options: FunctionInvokeOptions(body: try JSONSerialization.data(withJSONObject: payload))
            )
        } catch {
            // Best-effort surface server message.
            if let e = error as? FunctionsError {
                switch e {
                case let .httpError(_, data):
                    let text = String(data: data, encoding: .utf8) ?? ""
                    throw NSError(domain: "EmailTemplateAIFormatService", code: -1, userInfo: [NSLocalizedDescriptionKey: text.isEmpty ? "服务端错误" : text])
                default:
                    break
                }
            }
            throw error
        }
    }
}
