// Supabase Edge Function: email_template_format_ai
//
// One-click formatting for email templates.
// Returns formatted subject + HTML body while preserving {{variables}} and existing HTML.
//
// Security:
// - Deployed with --no-verify-jwt (gateway), but we DO requireUser(req)
// - Uses OPENAI_API_KEY on server; app sends no model keys.

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { requireUser } from "../_shared/supabase.ts"

type Json = string | number | boolean | null | { [key: string]: Json } | Json[]

type ReqBody = {
  workspace?: string
  subject: string
  body: string
  is_html?: boolean
  tone?: "japanese_minimal" | "default"
  language?: "zh" | "en"
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

function looksLikeHtml(s: string): boolean {
  // Very light heuristic: any tag-like pattern.
  return /<\s*\/?\s*[a-zA-Z][^>]*>/.test(s)
}

function extractTokens(text: string): string[] {
  const out: string[] = []
  const re = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g
  let m: RegExpExecArray | null
  while ((m = re.exec(text)) !== null) {
    out.push(m[0])
  }
  return Array.from(new Set(out))
}

function extractExistingTags(html: string): string[] {
  const tags = new Set<string>()
  const re = /<\s*\/?\s*([a-zA-Z][a-zA-Z0-9]*)\b/g
  let m: RegExpExecArray | null
  while ((m = re.exec(html)) !== null) {
    const t = (m[1] ?? "").toLowerCase()
    if (!t) continue
    tags.add(t)
  }
  return Array.from(tags)
}

async function callOpenAI(params: {
  subject: string
  body: string
  isHtml: boolean
  workspace: string
  tone: string
  language: string
}): Promise<{ subject: string; body_html: string; notes?: string }>
{
  const apiKey = getEnv("OPENAI_API_KEY")

  const tokens = extractTokens(params.subject + "\n" + params.body)
  const tags = params.isHtml ? extractExistingTags(params.body) : []

  const system = `你是一个严格的“邮件模版排版器（formatter）”。\n\n目标：只做排版（formatting），不要改变原意。输出将用于发送邮件的 HTML 正文。\n\n必须遵守：\n- 只返回 JSON（不要 markdown）。\n- 保留所有变量 token（例如 {{firstname}}）的字符串完全不变，不要改大小写/不要加空格。\n- 不要删除信息，不要杜撰新信息。\n- 如果输入已经包含 HTML 标签，请保留已有标签语义，避免破坏嵌套；可以在外层补结构（如 <p>、<div>）但不要打散已有 <a>/<b>/<i>/<span> 等。\n- 输出的 body_html 必须是可直接作为 email HTML body 的字符串（可以包含 <p>、<br>、<ul> 等）。\n- 不要添加 footer（统一结尾由系统另外拼接）。\n\n风格偏好：简洁、现代、日式极简，段落清晰，重点句可适度 <b>。\n语言：${params.language}.\nworkspace：${params.workspace}.\n`

  const user: Json = {
    input: {
      subject: params.subject,
      body: params.body,
      is_html: params.isHtml,
    },
    must_preserve_tokens: tokens,
    existing_html_tags: tags,
    output_format: {
      subject: "string",
      body_html: "string",
      notes: "string (optional)"
    },
    formatting_rules: [
      "主题：不改变含义，仅做必要的标点/空格整理（中文优先）。",
      "正文：段落化（p）+ 合理换行（br），避免一整坨文本。",
      "若识别到签名块（联系方式多行），请使用 <pre style=\"white-space:pre-wrap\"> 保留换行。",
      "如果输入是纯文本，请输出 HTML（用 <p>/<br>）。",
      "不要把 {{token}} 放进 HTML 属性里。"
    ]
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
  const subject = typeof parsed.subject === "string" ? parsed.subject : ""
  const body_html = typeof parsed.body_html === "string" ? parsed.body_html : ""
  const notes = typeof parsed.notes === "string" ? parsed.notes : undefined

  if (!subject && !body_html) throw new Error("OpenAI returned empty formatted result")

  return { subject, body_html, notes }
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

  const workspace = normalizeString(body.workspace) || "openhouse"
  const subject = normalizeString(body.subject)
  const rawBody = normalizeString(body.body)
  if (!subject && !rawBody) return badRequest("subject/body cannot both be empty")

  const isHtml = typeof body.is_html === "boolean" ? body.is_html : looksLikeHtml(rawBody)
  const tone = body.tone ?? "japanese_minimal"
  const language = body.language ?? "zh"

  try {
    const formatted = await callOpenAI({
      subject,
      body: rawBody,
      isHtml,
      workspace,
      tone,
      language,
    })

    return json({
      subject: formatted.subject,
      body_html: formatted.body_html,
      notes: formatted.notes ?? null,
    })
  } catch (e) {
    return json(
      { error: "format_failed", message: (e as Error)?.message ?? String(e) },
      { status: 500 }
    )
  }
})
