//
//  CRMAIContactImportService.swift
//  EstateMate
//

import Foundation
import Supabase

final class CRMAIContactImportService {
    struct ImportSummary: Decodable {
        var total: Int
        var toUpsert: Int?
        var skipped: Int
        var upserted: Int?
    }

    struct ContactPatch: Decodable {
        var fullName: String?
        var email: String?
        var phone: String?
        var notes: String?
        var tags: [String]?
        var stage: String?
        var source: String?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
            case email
            case phone
            case notes
            case tags
            case stage
            case source
        }
    }

    struct ImportRow: Decodable {
        var rowIndex: Int
        var action: String
        var reason: String?
        var patch: ContactPatch?
    }

    struct AnalyzeResponse: Decodable {
        var summary: ImportSummary
        var results: [ImportRow]
    }

    struct ApplyResponse: Decodable {
        var summary: ImportSummary
    }

    func analyze(fileName: String, data: Data) async throws -> AnalyzeResponse {
        try await call(mode: "analyze", fileName: fileName, data: data)
    }

    func apply(fileName: String, data: Data) async throws -> ApplyResponse {
        try await call(mode: "apply", fileName: fileName, data: data)
    }

    private func call<T: Decodable>(mode: String, fileName: String, data: Data) async throws -> T {
        let client = SupabaseClientProvider.client

        let payload: [String: Any] = [
            "mode": mode,
            "fileName": fileName,
            "fileBase64": data.base64EncodedString()
        ]

        do {
            return try await client.functions.invoke(
                "crm_import_contacts_ai",
                options: FunctionInvokeOptions(body: try JSONSerialization.data(withJSONObject: payload)),
                decoder: JSONDecoder.emDefault
            )
        } catch {
            // Best-effort surface server message.
            if let e = error as? FunctionsError {
                switch e {
                case let .httpError(_, data):
                    let text = String(data: data, encoding: .utf8) ?? ""
                    throw NSError(domain: "CRMAIContactImportService", code: -1, userInfo: [NSLocalizedDescriptionKey: text.isEmpty ? "服务端错误" : text])
                default:
                    break
                }
            }
            throw error
        }
    }
}

private extension JSONDecoder {
    static var emDefault: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
