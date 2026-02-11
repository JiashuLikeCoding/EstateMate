// Supabase Edge Function: openhouse_form_layout_ai
//
// AI auto layout for OpenHouse dynamic forms (schema: FormField[]).
// Returns reordered fields + inserted decoration/splice fields.
//
// Security:
// - Deployed with --no-verify-jwt (gateway), but we DO requireUser(req)
// - Uses OPENAI_API_KEY on server; app sends no model keys.

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { requireUser } from "../_shared/supabase.ts"

type Json = string | number | boolean | null | { [key: string]: Json } | Json[]

type ReqBody = {
  formName: string
  fields: any[]
  language?: "zh" | "en"
  tone?: "japanese_minimal" | "default"
}

function json(data: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...(init.headers ?? {}),
    },
  })
}

function badRequest(message: string, details?: unknown) {
  return json({ error: message, details }, { status: 400 })
}

function getEnv(name: string): string {
  const v = Deno.env.get(name)
  if (!v) throw new Error(`Missing env: ${name}`)
  return v
}

function normalizeString(v: unknown): string {
  if (v == null) return ""
  if (typeof v === "string") return v
  return String(v)
}

const AllowedTypes = new Set([
  // input
  "text",
  "multilineText",
  "phone",
  "email",
  "select",
  "dropdown",
  "multiSelect",
  "checkbox",
  "name",
  "date",
  "time",
  "address",
  // decoration/layout
  "sectionTitle",
  "sectionSubtitle",
  "divider",
  "splice",
])

function isValidField(f: any): boolean {
  if (!f || typeof f !== "object") return false
  if (typeof f.key !== "string" || !f.key.trim()) return false
  if (typeof f.type !== "string" || !AllowedTypes.has(f.type)) return false
  if (typeof f.label !== "string") return false
  if (typeof f.required !== "boolean") return false
  // options arrays can be absent
  return true
}

function ensureUniqueKeys(fields: any[]): any[] {
  const seen = new Set<string>()
  return fields.map((f, idx) => {
    let key = String(f.key ?? "").trim() || `ai_${idx}`
    const base = key
    let n = 1
    while (seen.has(key)) {
      key = `${base}_${n}`
      n++
    }
    seen.add(key)
    return { ...f, key }
  })
}

async function callOpenAI(params: {
  formName: string
  fields: any[]
  language: string
  tone: string
}): Promise<{ fields: any[]; notes?: string }>
{
  const apiKey = getEnv("OPENAI_API_KEY")

  const system = `你是一个严格的“OpenHouse 表单设计排版器”。\n\n任务：根据输入的字段列表（FormField[]），进行“排版/分组/排序”优化，使表单在 iPhone/iPad 上都更清晰易填。\n\n必须遵守：\n- 只返回 JSON（不要 markdown）。\n- 不要翻译语言：保持输入语言不变（中文保持中文，英文保持英文；混合则保持混合）。\n- 不要删除任何可提交字段（输入字段）。只允许：重排顺序 + 插入装饰字段（sectionTitle/sectionSubtitle/divider）+ 插入 splice 进行模块连接。\n- 不要修改原有输入字段的 key/type/required/options 等语义。\n- 装饰字段与 splice 必须 required=false。\n- sectionTitle/sectionSubtitle 的 label 用于展示文字；divider 的 label 可为空字符串。\n- 新增字段必须生成不会与现有 key 冲突的 key（例如：__ai_title_1、__ai_divider_2、__ai_splice_3）。\n\n排版规则（EstateMate）：\n- 现代极简/日式风格；模块化分组清晰。\n- 使用 sectionTitle 作为分组标题；必要时用 sectionSubtitle 补一句提示。\n- 同一组里的字段用 splice 连接（在字段之间插入 splice），让 UI 渲染成同组模块。\n- divider 用于组与组之间的分隔，但不要过密。\n- 开头优先放“联系方式”（name/phone/email 至少一项，如果存在就靠前）。\n- 之后按意向→预算/时间→地址→备注 的逻辑顺序。\n\n输出：返回新的 fields 数组。\n`

  const user: Json = {
    form_name: params.formName,
    input_fields: params.fields,
    output_format: {
      fields: "FormField[]",
      notes: "string?",
    },
  }

  const resp = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: system },
        { role: "user", content: JSON.stringify(user) },
      ],
    }),
  })

  if (!resp.ok) {
    const text = await resp.text()
    throw new Error(`OpenAI error: ${resp.status} ${text}`)
  }

  const data = await resp.json()
  const content = data?.choices?.[0]?.message?.content
  if (!content) throw new Error("OpenAI returned empty content")

  const parsed = JSON.parse(content)
  const fields = Array.isArray(parsed.fields) ? parsed.fields : []
  const notes = typeof parsed.notes === "string" ? parsed.notes : undefined

  return { fields, notes }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return badRequest("Only POST supported")

  const { user, errorResponse } = await requireUser(req)
  if (errorResponse || !user) return errorResponse!

  let body: ReqBody
  try {
    body = await req.json()
  } catch {
    return badRequest("Invalid JSON body")
  }

  const formName = normalizeString(body.formName)
  const fieldsIn = Array.isArray(body.fields) ? body.fields : []
  if (!formName && fieldsIn.length === 0) return badRequest("formName/fields cannot both be empty")

  const language = body.language ?? "zh"
  const tone = body.tone ?? "japanese_minimal"

  try {
    const out = await callOpenAI({ formName, fields: fieldsIn, language, tone })
    const cleaned = ensureUniqueKeys(out.fields).filter(isValidField)

    // Must not return empty fields if input had fields
    if (fieldsIn.length > 0 && cleaned.length == 0) {
      throw new Error("AI returned empty or invalid fields")
    }

    return json({ fields: cleaned, notes: out.notes ?? null })
  } catch (e) {
    return json(
      { error: "layout_failed", message: (e as Error)?.message ?? String(e) },
      { status: 500 }
    )
  }
})
