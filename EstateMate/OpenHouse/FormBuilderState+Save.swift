//
//  FormBuilderState+Save.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-19.
//

import Foundation

extension FormBuilderState {
    /// Save the current form state (create or update).
    /// - Throws: validation or network errors.
    func save(using service: DynamicFormService) async throws {
        // Never allow saving changes into an archived form.
        if formId != nil, isArchived {
            throw NSError(domain: "FormBuilder", code: 99, userInfo: [NSLocalizedDescriptionKey: "该表单已归档，无法修改。请先取消归档，或复制一个新表单再编辑。"])
        }

        // 1) Options validation
        for f in fields where (f.type == .select || f.type == .dropdown || f.type == .multiSelect) {
            if (f.options ?? []).isEmpty {
                throw NSError(domain: "FormBuilder", code: 1, userInfo: [NSLocalizedDescriptionKey: "字段 \"\(f.label)\" 需要选项"])
            }
        }

        // 2) Basic required presence
        // OpenHouse 现场表单必须至少能联系到客人：手机号/邮箱二选一。
        let hasPhoneOrEmail = fields.contains(where: { $0.type == .phone || $0.type == .email })
        if hasPhoneOrEmail == false {
            throw NSError(domain: "FormBuilder", code: 2, userInfo: [NSLocalizedDescriptionKey: "表单必须包含“手机号”或“邮箱”字段（至少一个），否则无法保存"])
        }

        // 3) Splice rules
        if fields.first?.type == .splice || fields.last?.type == .splice {
            throw NSError(domain: "FormBuilder", code: 3, userInfo: [NSLocalizedDescriptionKey: "拼接不能放在表单的开头或结尾"])
        }

        if fields.count >= 2 {
            for i in 1..<fields.count {
                if fields[i].type == .splice, fields[i - 1].type == .splice {
                    throw NSError(domain: "FormBuilder", code: 3, userInfo: [NSLocalizedDescriptionKey: "不允许两个拼接挨在一起"])
                }
            }
        }

        // Max chain: field splice field splice field splice field (max 4 fields, i.e. max 3 splices in a chain)
        var chainCount = 0
        for i in fields.indices {
            let f = fields[i]
            if f.type == .splice { continue }

            if i > 0, fields[i - 1].type == .splice {
                chainCount += 1
            } else {
                chainCount = 1
            }

            if chainCount > 4 {
                throw NSError(domain: "FormBuilder", code: 4, userInfo: [NSLocalizedDescriptionKey: "拼接最大支持一行 4 个字段（字段 拼接 字段 拼接 字段 拼接 字段）"])
            }
        }

        let schema = FormSchema(version: 1, fields: fields, presentation: presentation)

        let trimmedName = formName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            throw NSError(domain: "FormBuilder", code: 5, userInfo: [NSLocalizedDescriptionKey: "请填写表单名称"])
        }

        if let id = formId {
            _ = try await service.updateForm(id: id, name: trimmedName, schema: schema)
        } else {
            let created = try await service.createForm(name: trimmedName, schema: schema)
            formId = created.id
        }

        errorMessage = nil
        markSavedBaseline()
    }
}
