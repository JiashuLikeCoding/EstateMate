import { requireUser, supabaseServiceClient } from "../_shared/supabase.ts";

type SendBody = {
  to: string;
  subject: string;
  text?: string;
  html?: string;
  workspace?: string; // crm|openhouse
  threadId?: string;
  inReplyTo?: string;
  references?: string;
};

function base64UrlEncode(input: string): string {
  const bytes = new TextEncoder().encode(input);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  const b64 = btoa(binary);
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function containsNonAscii(s: string): boolean {
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c > 0x7e || c < 0x20) return true;
  }
  return false;
}

function base64EncodeUtf8(s: string): string {
  const bytes = new TextEncoder().encode(s);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary);
}

function rfc2047EncodeHeaderValue(value: string): string {
  return `=?UTF-8?B?${base64EncodeUtf8(value)}?=`;
}

function buildRfc822Message(params: {
  from: string;
  to: string;
  subject: string;
  text: string;
  html?: string;
  replyTo?: string | null;
  inReplyTo?: string | null;
  references?: string | null;
}): string {
  const boundary = `em_${crypto.randomUUID()}`;

  const headers: string[] = [];

  const fromValue = (() => {
    const raw = params.from.trim();
    const lt = raw.indexOf("<");
    const gt = raw.indexOf(">", lt + 1);
    if (lt > 0 && gt > lt) {
      const name = raw.slice(0, lt).trim().replace(/^\"|\"$/g, "");
      const addr = raw.slice(lt).trim();
      if (name && containsNonAscii(name)) {
        return `\"${rfc2047EncodeHeaderValue(name)}\" ${addr}`;
      }
      return raw;
    }
    return containsNonAscii(raw) ? rfc2047EncodeHeaderValue(raw) : raw;
  })();

  headers.push(`From: ${fromValue}`);
  headers.push(`To: ${params.to}`);

  const subjectHeader = containsNonAscii(params.subject)
    ? rfc2047EncodeHeaderValue(params.subject)
    : params.subject;
  headers.push(`Subject: ${subjectHeader}`);

  headers.push(`MIME-Version: 1.0`);
  if (params.replyTo) headers.push(`Reply-To: ${params.replyTo}`);
  if (params.inReplyTo) headers.push(`In-Reply-To: ${params.inReplyTo}`);
  if (params.references) headers.push(`References: ${params.references}`);

  if (params.html && params.html.trim().length > 0) {
    headers.push(`Content-Type: multipart/alternative; boundary=\"${boundary}\"`);

    const parts: string[] = [];
    parts.push(`--${boundary}`);
    parts.push(`Content-Type: text/plain; charset=\"UTF-8\"`);
    parts.push(`Content-Transfer-Encoding: 7bit`);
    parts.push("");
    parts.push(params.text);

    parts.push(`--${boundary}`);
    parts.push(`Content-Type: text/html; charset=\"UTF-8\"`);
    parts.push(`Content-Transfer-Encoding: 7bit`);
    parts.push("");
    parts.push(params.html);

    parts.push(`--${boundary}--`);
    return `${headers.join("\r\n")}\r\n\r\n${parts.join("\r\n")}`;
  }

  headers.push(`Content-Type: text/plain; charset=\"UTF-8\"`);
  headers.push(`Content-Transfer-Encoding: 7bit`);

  return `${headers.join("\r\n")}\r\n\r\n${params.text}`;
}

function envOptional(name: string): string | null {
  const v = Deno.env.get(name);
  return v && v.trim().length > 0 ? v.trim() : null;
}

function envRequired(name: string): string {
  const v = envOptional(name);
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

function googleClientConfig() {
  const clientId = envOptional("GOOGLE_OAUTH_CLIENT_ID") ?? envRequired("GOOGLE_OAUTH_WEB_CLIENT_ID");
  const clientSecret = envOptional("GOOGLE_OAUTH_CLIENT_SECRET") ?? envOptional("GOOGLE_OAUTH_WEB_CLIENT_SECRET");
  return { clientId, clientSecret };
}

async function googleRefreshAccessToken(refreshToken: string) {
  const { clientId, clientSecret } = googleClientConfig();

  const params = new URLSearchParams();
  params.set("client_id", clientId);
  if (clientSecret) params.set("client_secret", clientSecret);
  params.set("grant_type", "refresh_token");
  params.set("refresh_token", refreshToken);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: params,
  });

  const json = await res.json();
  if (!res.ok) {
    throw new Error(`google_refresh_failed: ${JSON.stringify(json)}`);
  }

  return json as {
    access_token: string;
    expires_in: number;
    scope?: string;
    token_type: string;
  };
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "method_not_allowed" }), {
        status: 405,
        headers: { "content-type": "application/json" },
      });
    }

    const { user, errorResponse } = await requireUser(req);
    if (errorResponse) return errorResponse;

    const body = (await req.json()) as Partial<SendBody>;
    const to = (body.to ?? "").trim();
    const subject = (body.subject ?? "").trim();
    const workspace = (body.workspace ?? "openhouse").trim();
    const threadId = (body.threadId ?? "").trim();
    const inReplyTo = (body.inReplyTo ?? "").trim();
    const references = (body.references ?? "").trim();
    const text = (body.text ?? "").toString();
    const html = body.html?.toString();

    if (!to || !subject || !text) {
      return new Response(JSON.stringify({ error: "bad_request" }), {
        status: 400,
        headers: { "content-type": "application/json" },
      });
    }

    const userId = user!.id;
    const admin = supabaseServiceClient();

    const { data: conn, error: connErr } = await admin
      .from("gmail_connections")
      .select("email,refresh_token")
      .eq("user_id", userId)
      .maybeSingle();

    if (connErr) {
      return new Response(JSON.stringify({ error: connErr.message }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }

    if (!conn?.refresh_token) {
      return new Response(JSON.stringify({ error: "gmail_not_connected" }), {
        status: 400,
        headers: { "content-type": "application/json" },
      });
    }

    const token = await googleRefreshAccessToken(conn.refresh_token);

    const { data: settings } = await admin
      .from("email_template_settings")
      .select("from_name")
      .eq("created_by", userId)
      .eq("workspace", workspace)
      .maybeSingle();

    const displayName = (settings?.from_name as string | undefined)?.trim() || envOptional("GMAIL_FROM_NAME") || "EstateMate";

    const fromHeader = conn.email
      ? `${displayName} <${conn.email}>`
      : (user!.email ?? "me");

    const replyTo = user!.email ?? null;

    const rfc822 = buildRfc822Message({
      from: fromHeader,
      to,
      subject,
      text,
      html,
      replyTo,
      inReplyTo: inReplyTo || null,
      references: references || null,
    });

    const raw = base64UrlEncode(rfc822);

    const sendBody: Record<string, unknown> = { raw };
    if (threadId) sendBody.threadId = threadId;

    const sendRes = await fetch("https://gmail.googleapis.com/gmail/v1/users/me/messages/send", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token.access_token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(sendBody),
    });

    const sendJson = await sendRes.json().catch(() => ({}));
    if (!sendRes.ok) {
      return new Response(
        JSON.stringify({ error: "gmail_send_failed", detail: sendJson }),
        { status: 502, headers: { "content-type": "application/json" } },
      );
    }

    const providerMessageId = (sendJson?.id as string | undefined) ?? null;

    return new Response(JSON.stringify({ ok: true, id: providerMessageId }), {
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
