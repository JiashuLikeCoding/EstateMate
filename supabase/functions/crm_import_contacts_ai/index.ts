// Supabase Edge Function: crm_import_contacts_ai
//
// Goal:
// - Accept CSV/XLSX uploads (base64) from iOS.
// - Use AI to map columns -> CRM contact schema.
// - Upsert into crm_contacts using the calling user's session.
//
// Security:
// - Deployed with --no-verify-jwt (gateway), but we DO requireUser(req)
// - We do NOT use service role for DB writes; we write as the user.

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "npm:@supabase/supabase-js@2"
import * as XLSX from "npm:xlsx@0.18.5"
import { requireUser } from "../_shared/supabase.ts"

type Json = string | number | boolean | null | { [key: string]: Json } | Json[]

type ImportMode = "analyze" | "apply"

type ContactPatch = {
  full_name?: string
  email?: string
  phone?: string
  notes?: string
  tags?: string[]
  stage?: string
  source?: string
}

type RowResult = {
  rowIndex: number
  action: "upsert" | "skip"
  reason?: string
  patch?: ContactPatch
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

function looksLikeEmail(s: string) {
  return /.+@.+\..+/.test(s)
}

function normalizeString(v: unknown): string {
  if (v == null) return ""
  if (typeof v === "string") return v.trim()
  return String(v).trim()
}

function parseCsv(csvText: string): Record<string, string>[] {
  // Simple CSV parser (commas + quotes). Good enough for typical exports.
  // If you need edge cases later, we can swap to a dedicated csv lib.
  const lines = csvText.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n").filter(l => l.trim().length > 0)
  if (lines.length === 0) return []

  const rows: string[][] = []
  for (const line of lines) {
    const out: string[] = []
    let cur = ""
    let inQuotes = false
    for (let i = 0; i < line.length; i++) {
      const ch = line[i]
      if (ch === '"') {
        if (inQuotes && line[i + 1] === '"') {
          cur += '"'
          i++
        } else {
          inQuotes = !inQuotes
        }
      } else if (ch === "," && !inQuotes) {
        out.push(cur)
        cur = ""
      } else {
        cur += ch
      }
    }
    out.push(cur)
    rows.push(out.map(s => s.trim()))
  }

  const header = rows[0]
  const data = rows.slice(1)
  return data.map(cols => {
    const obj: Record<string, string> = {}
    for (let i = 0; i < header.length; i++) {
      const key = header[i] ?? `col_${i + 1}`
      obj[key] = (cols[i] ?? "").trim()
    }
    return obj
  })
}

function parseXlsx(buf: Uint8Array): Record<string, string>[] {
  const wb = XLSX.read(buf, { type: "array" })
  const sheetName = wb.SheetNames[0]
  if (!sheetName) return []
  const ws = wb.Sheets[sheetName]
  const jsonRows = XLSX.utils.sheet_to_json<Record<string, unknown>>(ws, { defval: "" })
  return jsonRows.map(r => {
    const out: Record<string, string> = {}
    for (const [k, v] of Object.entries(r)) {
      out[k] = normalizeString(v)
    }
    return out
  })
}

async function aiMapRows(params: {
  template: Json
  rows: Record<string, string>[]
}): Promise<RowResult[]> {
  const apiKey = getEnv("OPENAI_API_KEY")

  // Keep token use bounded: sample up to 50 rows for mapping.
  const sample = params.rows.slice(0, 50)

  const system = `你是一个严格的“数据导入映射器”。\n\n任务：把用户上传的表格行（可能是 CSV / XLSX）映射到 CRM 客户字段。\n\n要求：\n- 只返回 JSON（不要 markdown）。\n- 每一行要输出 action=upsert 或 skip。\n- upsert 行必须至少包含 email 或 phone 之一；否则 skip 并给 reason。\n- 字段：full_name,email,phone,notes,tags,stage,source\n- tags：如果上传里是“逗号/顿号/空格”分隔的，拆成数组；否则可以空数组。\n- stage/source：如果找不到就不要乱猜；可以省略，让客户端/服务端用默认值。\n- notes：可以把未被映射的有价值信息合并进 notes（例如：预算、意向、备注列）。\n`

  const user = {
    template: params.template,
    input_columns: Object.keys(sample[0] ?? {}),
    sample_rows: sample,
    output_format: {
      rows: [
        {
          rowIndex: 1,
          action: "upsert",
          reason: "",
          patch: {
            full_name: "",
            email: "",
            phone: "",
            notes: "",
            tags: [""],
            stage: "",
            source: "",
          },
        },
      ],
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
      temperature: 0,
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

  let parsed: any
  try {
    parsed = JSON.parse(content)
  } catch {
    throw new Error("OpenAI returned non-JSON content")
  }

  const rows = parsed?.rows
  if (!Array.isArray(rows)) throw new Error("OpenAI JSON missing rows[]")

  // Ensure rowIndex is present and clamp to input size.
  return rows
    .map((r: any) => ({
      rowIndex: Number(r.rowIndex ?? 0),
      action: r.action === "skip" ? "skip" : "upsert",
      reason: typeof r.reason === "string" ? r.reason : undefined,
      patch: typeof r.patch === "object" && r.patch != null ? r.patch : undefined,
    }))
    .filter((r: RowResult) => r.rowIndex >= 1 && r.rowIndex <= params.rows.length)
}

function defaultTemplate(): Json {
  // This is the “existing data template” we give AI.
  // It mirrors crm_contacts columns we care about.
  return {
    crm_contact_fields: [
      { key: "full_name", type: "string", required: false, note: "客户姓名" },
      { key: "email", type: "string", required: false, note: "邮箱（唯一 key 之一）" },
      { key: "phone", type: "string", required: false, note: "手机号（唯一 key 之一）" },
      { key: "notes", type: "string", required: false, note: "备注" },
      { key: "tags", type: "string[]", required: false, note: "标签数组" },
      { key: "stage", type: "string", required: false, note: "阶段（可选）" },
      { key: "source", type: "string", required: false, note: "来源（可选）" },
    ],
  }
}

Deno.serve(async (req) => {
  try {
    const { user, token } = await requireUser(req)

    const body = await req.json().catch(() => null)
    if (!body) return badRequest("缺少 JSON body")

    const mode: ImportMode = body.mode === "apply" ? "apply" : "analyze"
    const fileName = normalizeString(body.fileName)
    const fileBase64 = normalizeString(body.fileBase64)

    if (!fileName || !fileBase64) return badRequest("缺少 fileName 或 fileBase64")

    const buf = Uint8Array.from(atob(fileBase64), (c) => c.charCodeAt(0))
    let rows: Record<string, string>[] = []

    const lower = fileName.toLowerCase()
    if (lower.endsWith(".csv")) {
      const text = new TextDecoder().decode(buf)
      rows = parseCsv(text)
    } else if (lower.endsWith(".xlsx") || lower.endsWith(".xls")) {
      rows = parseXlsx(buf)
    } else {
      // Try as CSV fallback
      const text = new TextDecoder().decode(buf)
      rows = parseCsv(text)
    }

    if (rows.length === 0) return badRequest("文件没有可导入的数据（空表或解析失败）")

    const template = defaultTemplate()
    const mapped = await aiMapRows({ template, rows })

    // Rebuild results aligned to input rows.
    const byIndex = new Map<number, RowResult>()
    for (const r of mapped) byIndex.set(r.rowIndex, r)

    const results: RowResult[] = []
    for (let i = 0; i < rows.length; i++) {
      const rowIndex = i + 1
      const r = byIndex.get(rowIndex)
      if (!r) {
        results.push({ rowIndex, action: "skip", reason: "AI 未返回该行映射" })
        continue
      }

      if (r.action !== "upsert") {
        results.push(r)
        continue
      }

      const patch = r.patch ?? {}
      const email = normalizeString(patch.email)
      const phone = normalizeString(patch.phone)

      if (!email && !phone) {
        results.push({ rowIndex, action: "skip", reason: r.reason ?? "缺少邮箱或手机号" })
        continue
      }
      if (email && !looksLikeEmail(email)) {
        // Keep phone-only if available.
        if (!phone) {
          results.push({ rowIndex, action: "skip", reason: "邮箱格式不正确，且没有手机号" })
          continue
        }
        patch.email = ""
      }

      // sanitize
      if (patch.full_name != null) patch.full_name = normalizeString(patch.full_name)
      if (patch.email != null) patch.email = normalizeString(patch.email).toLowerCase()
      if (patch.phone != null) patch.phone = normalizeString(patch.phone)
      if (patch.notes != null) patch.notes = normalizeString(patch.notes)
      if (Array.isArray(patch.tags)) {
        patch.tags = patch.tags.map((t) => normalizeString(t)).filter(Boolean)
      }

      results.push({ rowIndex, action: "upsert", patch })
    }

    if (mode === "analyze") {
      const summary = {
        total: results.length,
        toUpsert: results.filter((r) => r.action === "upsert").length,
        skipped: results.filter((r) => r.action === "skip").length,
      }
      return json({ summary, results })
    }

    // APPLY
    const url = getEnv("SUPABASE_URL")
    const anon = getEnv("SUPABASE_ANON_KEY")
    const supabase = createClient(url, anon, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const upserted: RowResult[] = []
    const skipped: RowResult[] = []

    for (const r of results) {
      if (r.action !== "upsert" || !r.patch) {
        skipped.push(r)
        continue
      }

      const p = r.patch
      const email = normalizeString(p.email)
      const phone = normalizeString(p.phone)

      // Choose conflict key: prefer email.
      // Note: DB unique constraints are expected to exist for email/phone; otherwise this will still insert.
      const onConflict = email ? "email" : (phone ? "phone" : null)
      if (!onConflict) {
        skipped.push({ rowIndex: r.rowIndex, action: "skip", reason: "缺少 email/phone" })
        continue
      }

      const payload: Record<string, Json> = {
        full_name: normalizeString(p.full_name),
        email: email || null,
        phone: phone || null,
        notes: normalizeString(p.notes),
        tags: Array.isArray(p.tags) ? p.tags : null,
      }
      if (p.stage) payload.stage = p.stage
      if (p.source) payload.source = p.source

      const { error } = await supabase
        .from("crm_contacts")
        .upsert(payload, { onConflict })

      if (error) {
        skipped.push({ rowIndex: r.rowIndex, action: "skip", reason: `写入失败：${error.message}` })
      } else {
        upserted.push(r)
      }
    }

    return json({
      summary: {
        total: results.length,
        upserted: upserted.length,
        skipped: skipped.length,
      },
      upserted,
      skipped,
      user_id: user.id,
    })
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, { status: 500 })
  }
})
