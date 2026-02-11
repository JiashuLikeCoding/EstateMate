import Foundation
import Supabase

final class EmailTemplateAIFormatService {
    struct SuggestedVariable: Decodable, Identifiable {
        var id: String { key }
        let key: String
        let label: String
        let reason: String?
        let original_snippet: String?
    }

    struct TokenCorrection: Decodable, Identifiable {
        var id: String { from + "->" + to }
        let from: String
        let to: String
        let reason: String?
    }

    struct TokenIssue: Decodable, Identifiable {
        var id: String { type + ":" + token }
        let type: String
        let token: String
        let suggestion: String?
        let message: String?
    }

    struct Response: Decodable {
        let name: String
        let subject: String
        let body_html: String
        let preview_body_html: String
        let diff_body_html: String
        let suggested_variables: [SuggestedVariable]
        let token_corrections: [TokenCorrection]
        let token_issues: [TokenIssue]
        let notes: String?
    }

    func format(workspace: EstateMateWorkspaceKind, name: String, subject: String, body: String, declaredKeys: [String]) async throws -> Response {
        let client = SupabaseClientProvider.client

        let payload: [String: Any] = [
            "workspace": workspace.rawValue,
            "name": name,
            "subject": subject,
            "body": body,
            "declared_keys": declaredKeys,
            "language": "en",
            "tone": "japanese_minimal"
        ]

        do {
            return try await client.functions.invoke(
                "email_template_format_ai",
                options: FunctionInvokeOptions(body: try JSONSerialization.data(withJSONObject: payload))
            )
        } catch {
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
