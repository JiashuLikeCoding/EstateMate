import Foundation
import Supabase

final class OpenHouseFormLayoutAIService {
    struct RequestBody: Encodable {
        let formName: String
        let fields: [FormField]
        let language: String
        let tone: String
    }

    struct ResponseBody: Decodable {
        let fields: [FormField]
        let notes: String?
    }

    func layout(formName: String, fields: [FormField]) async throws -> ResponseBody {
        let client = SupabaseClientProvider.client

        let req = RequestBody(
            formName: formName,
            fields: fields,
            language: "zh",
            tone: "japanese_minimal"
        )

        let body = try JSONEncoder.emDefault.encode(req)

        do {
            return try await client.functions.invoke(
                "openhouse_form_layout_ai",
                options: FunctionInvokeOptions(body: body),
                decoder: JSONDecoder.emDefault
            )
        } catch {
            if let e = error as? FunctionsError {
                switch e {
                case let .httpError(_, data):
                    let text = String(data: data, encoding: .utf8) ?? ""
                    throw NSError(domain: "OpenHouseFormLayoutAIService", code: -1, userInfo: [NSLocalizedDescriptionKey: text.isEmpty ? "服务端错误" : text])
                default:
                    break
                }
            }
            throw error
        }
    }
}

private extension JSONEncoder {
    static var emDefault: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

private extension JSONDecoder {
    static var emDefault: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
