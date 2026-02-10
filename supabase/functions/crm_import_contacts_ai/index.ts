// Supabase Edge Function: crm_import_contacts_ai
//
// Accepts CSV/XLSX (base64), uses AI to infer a column mapping once,
// then applies mapping to all rows deterministically (with regex fallbacks).
//
// Security:
// - Deployed with --no-verify-jwt (gateway), but we DO requireUser(req)
// - DB writes are done as the user via anon key + Authorization header.

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

function createdAtFromSourceTime(sourceTime: string | null | undefined): string | null {
  const s = normalizeString(sourceTime)
  if (!s) return null
  // We normalize source_time to YYYY-MM-DD (date-only). Store as UTC start-of-day.
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return `${s}T00:00:00.000Z`
  // If it's already ISO-ish, just trust it.
  return s
}

type RowResult = {
  rowIndex: number
  action: "upsert" | "skip"
  reason?: string
  source_time?: string
  patch?: ContactPatch
}

type ColumnMapping = {
  full_name?: string
  email?: string
  phone?: string
  notes?: string[]
  tags?: string
  stage?: string
  source?: string
  extras_to_notes?: boolean
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
  if (typeof v === "string") return v.trim()
  return String(v).trim()
}

function normalizeEmail(v: unknown): string {
  return normalizeString(v).toLowerCase()
}

function extractFirstEmail(text: string): string | null {
  const m = text.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)
  return m ? m[0].toLowerCase() : null
}

function normalizePhoneCandidate(text: string): string {
  // Keep + and digits. Remove spaces/dashes/brackets.
  const s = text.replace(/[^\d+]/g, "")
  return s
}

function looksLikeYyyyMmDdDigits(s: string): boolean {
  if (!/^\d{8}$/.test(s)) return false
  const year = Number(s.slice(0, 4))
  const month = Number(s.slice(4, 6))
  const day = Number(s.slice(6, 8))
  if (year < 1900 || year > 2100) return false
  if (month < 1 || month > 12) return false
  if (day < 1 || day > 31) return false
  return true
}

function extractFirstPhone(text: string): string | null {
  // Heuristic: extract a 10-15 digit phone (optionally starting with +)
  // Avoid treating dates like 20240504 as phone.
  const cleaned = normalizePhoneCandidate(text)

  // If it's exactly 8 digits and looks like YYYYMMDD, ignore.
  const digitsOnly = cleaned.replace(/^\+/, "")
  if (looksLikeYyyyMmDdDigits(digitsOnly)) return null

  const m = cleaned.match(/\+?\d{10,15}/)
  return m ? m[0] : null
}

function splitTags(raw: string): string[] {
  const s = raw.trim()
  if (!s) return []
  return s
    .split(/[,，、;；\s]+/)
    .map((t) => t.trim())
    .filter(Boolean)
}

function parseCsv(csvText: string): Record<string, string>[] {
  const lines = csvText
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .split("\n")
    .filter((l) => l.trim().length > 0)
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
    rows.push(out.map((s) => s.trim()))
  }

  const header = rows[0]
  const data = rows.slice(1)
  return data.map((cols) => {
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
  const jsonRows = XLSX.utils.sheet_to_json<Record<string, unknown>>(ws, { defval: "", raw: false })
  return jsonRows.map((r) => {
    const out: Record<string, string> = {}
    for (const [k, v] of Object.entries(r)) {
      out[k] = normalizeString(v)
    }
    return out
  })
}

function defaultTemplate(): Json {
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

async function aiInferMapping(params: { template: Json; columns: string[]; sampleRows: Record<string, string>[] }): Promise<ColumnMapping> {
  const apiKey = getEnv("OPENAI_API_KEY")

  const system = `你是一个严格的“表格列映射器”。\n\n任务：根据列名与样例行，推断哪些列对应 CRM 客户字段。\n\n必须遵守：\n- 只返回 JSON（不要 markdown）。\n- 你输出的是“列名映射”，不是逐行结果。\n- 如果不确定某个字段对应哪一列，请省略该字段，不要瞎猜。\n- notes 可以是多个列名数组（会合并进备注）。\n- extras_to_notes: true 表示把未被映射的列也以“key: value”附加到备注里。\n\nCRM 字段：full_name,email,phone,notes,tags,stage,source\n`

  const user = {
    template: params.template,
    input_columns: params.columns,
    sample_rows: params.sampleRows.slice(0, 10),
    output_format: {
      full_name: "列名",
      email: "列名",
      phone: "列名",
      tags: "列名",
      notes: ["列名"],
      stage: "列名",
      source: "列名",
      extras_to_notes: true,
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

  const parsed = JSON.parse(content)
  const mapping: ColumnMapping = {
    full_name: typeof parsed.full_name === "string" ? parsed.full_name : undefined,
    email: typeof parsed.email === "string" ? parsed.email : undefined,
    phone: typeof parsed.phone === "string" ? parsed.phone : undefined,
    tags: typeof parsed.tags === "string" ? parsed.tags : undefined,
    stage: typeof parsed.stage === "string" ? parsed.stage : undefined,
    source: typeof parsed.source === "string" ? parsed.source : undefined,
    extras_to_notes: typeof parsed.extras_to_notes === "boolean" ? parsed.extras_to_notes : true,
    notes: Array.isArray(parsed.notes) ? parsed.notes.filter((x: any) => typeof x === "string") : [],
  }

  return mapping
}

function isIdLikeColumn(name: string): boolean {
  const raw = name.trim().toLowerCase()
  if (!raw) return false
  // Normalize separators to spaces then split into tokens.
  const tokens = raw.replace(/[^a-z0-9]+/g, " ").trim().split(/\s+/).filter(Boolean)
  if (tokens.includes("id") || tokens.includes("uuid")) return true
  if (raw === "id" || raw === "uuid") return true
  if (raw.endsWith("_id") || raw.startsWith("id_") || raw.endsWith("-id") || raw.startsWith("id-")) return true
  // Common variants
  if (raw.includes("submission_id") || raw.includes("contact_id") || raw.includes("event_id") || raw.includes("form_id")) return true
  return false
}

function isTimeLikeColumn(name: string): boolean {
  const raw = name.trim().toLowerCase()
  if (!raw) return false
  const compact = raw.replace(/\s+/g, "")
  // obvious keywords
  if (
    compact.includes("createdat") ||
    compact.includes("updatedat") ||
    compact.includes("timestamp") ||
    compact.includes("datetime") ||
    compact.includes("date") ||
    compact.includes("time")
  ) return true

  // common spreadsheet labels
  if (raw.includes("提交") || raw.includes("时间") || raw.includes("日期")) return true

  return false
}

function normalizeSourceTime(value: string): string | null {
  const v = value.trim()
  if (!v) return null

  // If it's 8 digits like 20240504, treat as date.
  const digits = v.replace(/[^0-9]/g, "")
  if (digits.length === 8 && looksLikeYyyyMmDdDigits(digits)) {
    return `${digits.slice(0, 4)}-${digits.slice(4, 6)}-${digits.slice(6, 8)}`
  }

  const t = Date.parse(v)
  if (!Number.isNaN(t)) {
    const d = new Date(t)
    const yyyy = d.getUTCFullYear()
    const mm = String(d.getUTCMonth() + 1).padStart(2, "0")
    const dd = String(d.getUTCDate()).padStart(2, "0")
    return `${yyyy}-${mm}-${dd}`
  }

  return null
}

function applyMappingToRow(row: Record<string, string>, mapping: ColumnMapping): { patch: ContactPatch; sourceTime: string | null } {
  const used = new Set<string>()

  const get = (col?: string) => {
    if (!col) return ""
    used.add(col)
    return normalizeString(row[col])
  }

  let fullName = get(mapping.full_name)
  let email = normalizeEmail(get(mapping.email))
  let phone = normalizeString(get(mapping.phone))

  // Regex fallbacks: scan all values if missing.
  if (!email) {
    for (const [k, v] of Object.entries(row)) {
      // skip time/id-like columns to reduce false positives
      if (isTimeLikeColumn(k) || isIdLikeColumn(k)) continue
      const e = extractFirstEmail(normalizeString(v))
      if (e) {
        email = e
        break
      }
    }
  }
  if (!phone) {
    for (const [k, v] of Object.entries(row)) {
      if (isTimeLikeColumn(k) || isIdLikeColumn(k)) continue
      const p = extractFirstPhone(normalizeString(v))
      if (p) {
        phone = p
        break
      }
    }
  }

  const notesParts: string[] = []
  for (const col of mapping.notes ?? []) {
    const v = get(col)
    if (v) notesParts.push(`${col}: ${v}`)
  }

  const tagsRaw = get(mapping.tags)
  const tags = tagsRaw ? splitTags(tagsRaw) : []

  const stage = get(mapping.stage)
  const source = get(mapping.source)

  if (mapping.extras_to_notes !== false) {
    for (const [k, v] of Object.entries(row)) {
      if (used.has(k)) continue
      if (isIdLikeColumn(k)) continue
      const vv = normalizeString(v)
      if (!vv) continue
      notesParts.push(`${k}: ${vv}`)
    }
  }

  // Find a source time (for preview + optionally add to notes)
  let sourceTime: string | null = null
  for (const [k, v] of Object.entries(row)) {
    if (!isTimeLikeColumn(k)) continue
    const st = normalizeSourceTime(normalizeString(v))
    if (st) {
      sourceTime = st
      break
    }
  }
  const notes = notesParts.join("\n")

  const patch: ContactPatch = {}
  if (fullName) patch.full_name = fullName
  if (email) patch.email = email
  if (phone) patch.phone = phone
  if (notes) patch.notes = notes
  if (tags.length) patch.tags = tags
  if (stage) patch.stage = stage
  if (source) patch.source = source

  return { patch, sourceTime }
}

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization") ?? ""
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : ""

    const { user, errorResponse } = await requireUser(req)
    if (errorResponse || !user) return errorResponse!

    const body = await req.json().catch(() => null)
    if (!body) return badRequest("缺少 JSON body")

    const mode: ImportMode = body.mode === "apply" ? "apply" : "analyze"
    const fileName = normalizeString(body.fileName)
    const fileBase64 = normalizeString(body.fileBase64)

    const selectedRowIndices: number[] | null = Array.isArray(body.selectedRowIndices)
      ? body.selectedRowIndices.map((n: any) => Number(n)).filter((n: any) => Number.isFinite(n) && n > 0)
      : null

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
      const text = new TextDecoder().decode(buf)
      rows = parseCsv(text)
    }

    if (rows.length === 0) return badRequest("文件没有可导入的数据（空表或解析失败）")

    const columns = Array.from(
      rows.reduce((set, r) => {
        for (const k of Object.keys(r)) set.add(k)
        return set
      }, new Set<string>())
    )

    const template = defaultTemplate()
    const mapping = await aiInferMapping({ template, columns, sampleRows: rows })

    const results: RowResult[] = []
    for (let i = 0; i < rows.length; i++) {
      const rowIndex = i + 1
      const mapped = applyMappingToRow(rows[i], mapping)
      const patch = mapped.patch

      const email = normalizeString(patch.email)
      const phone = normalizeString(patch.phone)

      if (!email && !phone) {
        results.push({ rowIndex, action: "skip", reason: "缺少 email 和 phone（无法匹配唯一客户）", source_time: mapped.sourceTime ?? undefined })
      } else {
        results.push({ rowIndex, action: "upsert", patch, source_time: mapped.sourceTime ?? undefined })
      }
    }

    if (mode === "analyze") {
      const summary = {
        total: results.length,
        toUpsert: results.filter((r) => r.action === "upsert").length,
        skipped: results.filter((r) => r.action === "skip").length,
      }
      return json({ mapping, summary, results })
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

    const selectedSet = selectedRowIndices ? new Set<number>(selectedRowIndices) : null

    for (const r of results) {
      if (selectedSet && !selectedSet.has(r.rowIndex)) {
        skipped.push({ rowIndex: r.rowIndex, action: "skip", reason: "未选中" })
        continue
      }

      if (r.action !== "upsert" || !r.patch) {
        skipped.push(r)
        continue
      }

      const p = r.patch
      const email = normalizeEmail(p.email)
      const phone = normalizeString(p.phone)

      const onConflict = email ? "email" : phone ? "phone" : null
      if (!onConflict) {
        skipped.push({ rowIndex: r.rowIndex, action: "skip", reason: "缺少 email/phone" })
        continue
      }

      const basePayload: Record<string, Json> = {
        full_name: normalizeString(p.full_name),
        email: email || null,
        phone: phone || null,
        notes: normalizeString(p.notes),
        tags: Array.isArray(p.tags) ? p.tags : null,
      }
      if (p.stage) basePayload.stage = p.stage
      if (p.source) basePayload.source = p.source

      const createdAt = createdAtFromSourceTime(r.source_time)

      // We MUST NOT overwrite created_at for existing contacts.
      // So we do: check existence -> insert(with created_at) OR update(without created_at).
      const existing = email
        ? await supabase.from("crm_contacts").select("id").eq("email", email).maybeSingle()
        : await supabase.from("crm_contacts").select("id").eq("phone", phone).maybeSingle()

      if (existing.error) {
        skipped.push({ rowIndex: r.rowIndex, action: "skip", reason: `查询失败：${existing.error.message}` })
        continue
      }

      if (existing.data?.id) {
        const { error } = await supabase.from("crm_contacts").update(basePayload).eq("id", existing.data.id)
        if (error) {
          skipped.push({ rowIndex: r.rowIndex, action: "skip", reason: `更新失败：${error.message}` })
        } else {
          upserted.push(r)
        }
      } else {
        const payload: Record<string, Json> = { ...basePayload }
        if (createdAt) payload.created_at = createdAt

        const { error } = await supabase.from("crm_contacts").insert(payload)
        if (error) {
          skipped.push({ rowIndex: r.rowIndex, action: "skip", reason: `写入失败：${error.message}` })
        } else {
          upserted.push(r)
        }
      }
    }

    return json({
      mapping,
      summary: {
        total: selectedSet ? selectedSet.size : results.length,
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
