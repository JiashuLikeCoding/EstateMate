// Supabase Edge Function: email_template_format_ai
//
// AI: format + variable suggestions + token validation + diff highlight.
//
// Security:
// - Deployed with --no-verify-jwt (gateway), but we DO requireUser(req)
// - Uses OPENAI_API_KEY on server; app sends no model keys.

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { requireUser } from "../_shared/supabase.ts"
import DiffMatchPatch from "npm:diff-match-patch@1.0.5"

type Json = string | number | boolean | null | { [key: string]: Json } | Json[]

type ReqBody = {
  workspace?: string
  name?: string
  subject: string
  body: string
  declared_keys?: string[]
  is_html?: boolean
  tone?: "japanese_minimal" | "default"
  language?: "zh" | "en"
}

type SuggestedVariable = {
  key: string
  label: string
  reason?: string
  original_snippet?: string
}

type TokenIssue = {
  type: "unknown_token" | "typo_suspected" | "should_use_builtin"
  token: string
  suggestion?: string
  message?: string
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

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;")
}

function wrapAsEmailHtml(inner: string, opts: { highlightTokens?: boolean } = {}): string {
  const highlightTokens = opts.highlightTokens === true

  // Minimal email-safe wrapper for preview/diff.
  // NOTE: Token highlighting is for preview ONLY. It does not modify the email HTML saved/sent.
  const tokenCSS = highlightTokens
    ? `
  .em-token { color: #15803d; font-weight: 600; background: rgba(34, 197, 94, 0.10); padding: 0 2px; border-radius: 4px; }
`
    : ""

  const tokenJS = highlightTokens
    ? `
<script>
(function(){
  function walk(node){
    if(!node) return;
    if(node.nodeType === Node.TEXT_NODE){
      const text = node.nodeValue;
      if(!text || text.indexOf('{{') === -1) return;
      const re = /\{\{\s*[a-zA-Z0-9_]+\s*\}\}/g;
      let m; let last = 0;
      const parts = [];
      while((m = re.exec(text))){
        const start = m.index;
        const end = start + m[0].length;
        parts.push(text.slice(last, start));
        parts.push({token: m[0]});
        last = end;
      }
      if(parts.length === 0) return;
      parts.push(text.slice(last));
      const frag = document.createDocumentFragment();
      for(const p of parts){
        if(typeof p === 'string') frag.appendChild(document.createTextNode(p));
        else {
          const span = document.createElement('span');
          span.className = 'em-token';
          span.textContent = p.token;
          frag.appendChild(span);
        }
      }
      node.parentNode && node.parentNode.replaceChild(frag, node);
      return;
    }
    if(node.nodeType === Node.ELEMENT_NODE){
      const tag = (node.tagName || '').toLowerCase();
      if(tag === 'script' || tag === 'style' || tag === 'textarea' || tag === 'code' || tag === 'pre') return;
      const kids = Array.from(node.childNodes);
      for(const k of kids) walk(k);
    }
  }
  document.addEventListener('DOMContentLoaded', function(){
    walk(document.body);
  });
})();
</script>
`
    : ""

  return `<!doctype html><html><head><meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif; color:#222; line-height:1.55; padding: 14px; }
  p { margin: 0 0 10px 0; }
  pre { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace; font-size: 13px; }
  .diff del { color: #b42318; text-decoration: line-through; background: rgba(244, 63, 94, 0.08); }
  .diff ins { color: #b42318; text-decoration: none; background: rgba(244, 63, 94, 0.14); }
  .diff ins, .diff del { padding: 0 2px; border-radius: 4px; }
${tokenCSS}
</style>${tokenJS}</head><body>${inner}</body></html>`
}

function extractTokenKeys(text: string): string[] {
  const out: string[] = []
  const re = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g
  let m: RegExpExecArray | null
  while ((m = re.exec(text)) !== null) {
    const key = m[1] ?? ""
    if (key) out.push(key)
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

function builtInKeysForWorkspace(workspace: string): string[] {
  if (workspace === "openhouse") {
    return ["firstname", "lastname", "middle_name", "address", "date", "time", "event_title"]
  }
  return []
}

function computeDiffHtml(original: string, formatted: string): string {
  const dmp = new DiffMatchPatch()
  const diffs = dmp.diff_main(original, formatted)
  dmp.diff_cleanupSemantic(diffs)

  let out = ""
  for (const [op, data] of diffs as any[]) {
    const safe = escapeHtml(String(data ?? ""))
    if (op === 0) out += safe
    else if (op === -1) out += `<del>${safe}</del>`
    else if (op === 1) out += `<ins>${safe}</ins>`
  }

  // We are showing the diff of the raw HTML string; render as monospace pre so tags are readable.
  const pre = `<pre class="diff" style="white-space:pre-wrap; word-break:break-word;">${out}</pre>`
  return wrapAsEmailHtml(pre)
}

function applyTokenCorrections(text: string, corrections: { from: string; to: string }[]): string {
  var out = text
  for (const c of corrections) {
    const from = normalizeString(c.from)
    const to = normalizeString(c.to)
    if (!from || !to || from === to) continue
    out = out.split(from).join(to)
  }
  return out
}

async function callOpenAI(params: {
  name: string
  subject: string
  body: string
  isHtml: boolean
  workspace: string
  tone: string
  language: string
  builtInKeys: string[]
}): Promise<{
  name: string
  subject: string
  body_html: string
  suggested_variables: SuggestedVariable[]
  token_corrections: { from: string; to: string; reason?: string }[]
  notes?: string
}> {
  const apiKey = getEnv("OPENAI_API_KEY")

  const existingTokens = extractTokenKeys(params.name + "\n" + params.subject + "\n" + params.body)
  const tags = params.isHtml ? extractExistingTags(params.body) : []

  const system = `你是一个严格的“邮件模版智能排版器/校对器”。\n\n目标：\n1) 对“名称/主题/正文”做轻量排版与纠错：名称与主题更简洁专业；正文输出为适合邮件发送的 HTML（body_html）。\n2) 识别文本中未来可能要做成变量的内容（suggested_variables）。\n3) 检查变量 token 是否拼错/用错，并给出 token_corrections（只做建议，不要直接改 token 字符串）。\n\n必须遵守：\n- 不要翻译语言：保持输入的语言不变（中文保持中文，英文保持英文；混合则保持混合）。\n- 只返回 JSON（不要 markdown）。\n- 不要杜撰新信息，不要删除关键信息。\n- 已存在的 token（{{key}}）必须原样保留在 name/subject/body_html 里（不要改大小写/不要加空格）。\n- 如果输入包含 HTML 标签，尽量保持已有标签语义；可以补 <p>/<br>/<ul> 结构。\n- 不要添加 footer（统一结尾由系统另外拼接）。\n- suggested_variables 的 key 必须只含 a-z/0-9/_，小写。\n\nworkspace：${params.workspace}\n语言：${params.language}\n内置变量（如果适用）：${params.builtInKeys.join(",")}\n`

  const user: Json = {
    input: {
      name: params.name,
      subject: params.subject,
      body: params.body,
      is_html: params.isHtml,
    },
    existing_tokens: existingTokens.map((k) => `{{${k}}}`),
    built_in_keys: params.builtInKeys,
    existing_html_tags: tags,
    output_format: {
      name: "string",
      subject: "string",
      body_html: "string",
      suggested_variables: [
        { key: "string", label: "string", reason: "string?", original_snippet: "string?" },
      ],
      token_corrections: [
        { from: "{{bad_token}}", to: "{{good_token}}", reason: "string?" },
      ],
      notes: "string?",
    },
    guidelines: [
      "不要翻译语言：保持输入的语言不变（中文保持中文，英文保持英文；混合则保持混合）。",
      "只建议变量，不要自动把普通文本替换成 {{token}}。",
      "拼写修正优先针对英文单词错误，不要改变专有名词/品牌名/地址。",
      "如果发现 token 可能拼错（如 firstname/lastname），在 token_corrections 里给建议。",
    ],
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
  const name = typeof parsed.name === "string" ? parsed.name : params.name
  const subject = typeof parsed.subject === "string" ? parsed.subject : ""
  const body_html = typeof parsed.body_html === "string" ? parsed.body_html : ""
  const notes = typeof parsed.notes === "string" ? parsed.notes : undefined

  const suggested_variables: SuggestedVariable[] = Array.isArray(parsed.suggested_variables)
    ? parsed.suggested_variables
        .filter((x: any) => x && typeof x.key === "string" && typeof x.label === "string")
        .map((x: any) => ({
          key: String(x.key),
          label: String(x.label),
          reason: typeof x.reason === "string" ? x.reason : undefined,
          original_snippet: typeof x.original_snippet === "string" ? x.original_snippet : undefined,
        }))
    : []

  const token_corrections: { from: string; to: string; reason?: string }[] = Array.isArray(parsed.token_corrections)
    ? parsed.token_corrections
        .filter((x: any) => x && typeof x.from === "string" && typeof x.to === "string")
        .map((x: any) => ({
          from: String(x.from),
          to: String(x.to),
          reason: typeof x.reason === "string" ? x.reason : undefined,
        }))
    : []

  if (!name && !subject && !body_html) throw new Error("OpenAI returned empty formatted result")

  return { name, subject, body_html, suggested_variables, token_corrections, notes }
}

function validateTokens(params: {
  workspace: string
  text: string
  declaredKeys: string[]
}): TokenIssue[] {
  const issues: TokenIssue[] = []
  const keys = extractTokenKeys(params.text)
  const declared = new Set(params.declaredKeys)
  const builtIn = new Set(builtInKeysForWorkspace(params.workspace))

  for (const k of keys) {
    if (builtIn.has(k)) continue
    if (declared.has(k)) continue
    issues.push({
      type: "unknown_token",
      token: `{{${k}}}`,
      message: "该变量未在模板变量中声明（也不是内置变量）。",
    })
  }

  return issues
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
  const rawName = normalizeString(body.name)
  const subject = normalizeString(body.subject)
  const rawBody = normalizeString(body.body)
  if (!subject && !rawBody) return badRequest("subject/body cannot both be empty")

  const isHtml = typeof body.is_html === "boolean" ? body.is_html : looksLikeHtml(rawBody)
  const tone = body.tone ?? "japanese_minimal"
  const language = body.language ?? "zh"
  const builtInKeys = builtInKeysForWorkspace(workspace)

  try {
    const formatted = await callOpenAI({
      name: rawName,
      subject,
      body: rawBody,
      isHtml,
      workspace,
      tone,
      language,
      builtInKeys,
    })

    // Apply token corrections automatically (so preview/save reflects fixes).
    const correctedName = applyTokenCorrections(formatted.name ?? rawName, formatted.token_corrections)
    const correctedSubject = applyTokenCorrections(formatted.subject, formatted.token_corrections)
    const correctedBodyHTML = applyTokenCorrections(formatted.body_html, formatted.token_corrections)

    const tokenIssues = validateTokens({
      workspace,
      text: correctedName + "\n" + correctedSubject + "\n" + correctedBodyHTML,
      declaredKeys: Array.isArray(body.declared_keys) ? body.declared_keys.filter((x) => typeof x === "string") : [],
    })

    // Diff highlight: show AI-changes only.
    const diff_body_html = computeDiffHtml(rawBody, correctedBodyHTML)
    const preview_body_html = wrapAsEmailHtml(correctedBodyHTML, { highlightTokens: true })

    return json({
      name: correctedName,
      subject: correctedSubject,
      body_html: correctedBodyHTML,
      preview_body_html,
      diff_body_html,
      suggested_variables: formatted.suggested_variables,
      token_corrections: formatted.token_corrections,
      token_issues: tokenIssues,
      notes: formatted.notes ?? null,
    })
  } catch (e) {
    return json(
      { error: "format_failed", message: (e as Error)?.message ?? String(e) },
      { status: 500 }
    )
  }
})
