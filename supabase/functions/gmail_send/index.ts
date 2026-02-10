import { requireUser, supabaseServiceClient } from "../_shared/supabase.ts";

type SendBody = {
  to: string;
  subject: string;
  text?: string;
  html?: string;
  submissionId: string;
  threadId?: string;
  inReplyTo?: string;
  references?: string;
};

function base64UrlEncode(input: string): string {
  // btoa expects binary string; Gmail raw expects base64url of the RFC822 message bytes.
  // For our ASCII-only headers + UTF-8 body, TextEncoder is safer.
  const bytes = new TextEncoder().encode(input);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  const b64 = btoa(binary);
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function containsNonAscii(s: string): boolean {
  // Anything outside 0x20-0x7E likely needs RFC 2047 encoding in headers.
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
  // RFC 2047 encoded-word, Base64, UTF-8.
  // Example: =?UTF-8?B?5L2g5aW9?=
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
  // Minimal RFC 822 message. Gmail API will accept this format.
  // Use CRLF line endings.
  const boundary = `em_${crypto.randomUUID()}`;

  const headers: string[] = [];

  // Encode display name in From if needed, e.g. "嘉树 <a@b.com>".
  const fromValue = (() => {
    const raw = params.from.trim();
    const lt = raw.indexOf("<");
    const gt = raw.indexOf(">", lt + 1);
    if (lt > 0 && gt > lt) {
      const name = raw.slice(0, lt).trim().replace(/^"|"$/g, "");
      const addr = raw.slice(lt).trim();
      if (name && containsNonAscii(name)) {
        return `"${rfc2047EncodeHeaderValue(name)}" ${addr}`;
      }
      return raw;
    }
    // If the whole value contains non-ascii, encode as a last resort.
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
    headers.push(`Content-Type: multipart/alternative; boundary="${boundary}"`);

    const parts: string[] = [];
    parts.push(`--${boundary}`);
    parts.push(`Content-Type: text/plain; charset="UTF-8"`);
    parts.push(`Content-Transfer-Encoding: 7bit`);
    parts.push("");
    parts.push(params.text);

    parts.push(`--${boundary}`);
    parts.push(`Content-Type: text/html; charset="UTF-8"`);
    parts.push(`Content-Transfer-Encoding: 7bit`);
    parts.push("");
    parts.push(params.html);

    parts.push(`--${boundary}--`);
    return `${headers.join("\r\n")}\r\n\r\n${parts.join("\r\n")}`;
  }

  headers.push(`Content-Type: text/plain; charset="UTF-8"`);
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
  // Prefer new generic names; fall back to legacy WEB_* secrets.
  const clientId = envOptional("GOOGLE_OAUTH_CLIENT_ID") ?? envRequired("GOOGLE_OAUTH_WEB_CLIENT_ID");
  const clientSecret = envOptional("GOOGLE_OAUTH_CLIENT_SECRET") ?? envOptional("GOOGLE_OAUTH_WEB_CLIENT_SECRET");
  return { clientId, clientSecret };
}

async function googleRefreshAccessToken(refreshToken: string) {
  const { clientId, clientSecret } = googleClientConfig();

  const params = new URLSearchParams();
  params.set("client_id", clientId);
  // For iOS/installed-app OAuth clients, client_secret should NOT be sent.
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
    const submissionId = (body.submissionId ?? "").trim();
    const threadId = (body.threadId ?? "").trim();
    const inReplyTo = (body.inReplyTo ?? "").trim();
    const references = (body.references ?? "").trim();
    const text = (body.text ?? "").toString();
    const html = body.html?.toString();

    if (!to || !subject || !submissionId) {
      return new Response(JSON.stringify({ error: "bad_request" }), {
        status: 400,
        headers: { "content-type": "application/json" },
      });
    }

    const userId = user!.id;

    const admin = supabaseServiceClient();

    // 1) Dedup: claim this submissionId.
    const { error: claimErr } = await admin
      .from("openhouse_auto_emails")
      .upsert(
        {
          created_by: userId,
          submission_id: submissionId,
          to_email: to,
          subject,
          body_text: text,
          body_html: html ?? null,
          provider: "gmail",
          status: "sending",
        },
        { onConflict: "created_by,submission_id", ignoreDuplicates: true },
      );

    if (claimErr) {
      return new Response(JSON.stringify({ error: claimErr.message }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }

    // If row already existed, ignoreDuplicates will do nothing but still returns ok.
    // We re-check whether a row exists with sent_at set; if so, treat as already sent.
    const { data: existing, error: existingErr } = await admin
      .from("openhouse_auto_emails")
      .select("id,status,sent_at")
      .eq("created_by", userId)
      .eq("submission_id", submissionId)
      .maybeSingle();

    if (existingErr) {
      return new Response(JSON.stringify({ error: existingErr.message }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }

    if (existing?.sent_at) {
      return new Response(
        JSON.stringify({ ok: true, alreadySent: true }),
        { headers: { "content-type": "application/json" } },
      );
    }

    // 2) Load refresh_token.
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
      return new Response(
        JSON.stringify({ error: "gmail_not_connected" }),
        { status: 400, headers: { "content-type": "application/json" } },
      );
    }

    // 3) Refresh access token.
    const token = await googleRefreshAccessToken(conn.refresh_token);

    const fromEmail = conn.email || user!.email || "me";

    // Gmail inbox list shows the sender display name (if present). If we only send the raw email,
    // Gmail iOS will show something like "4524...@gmail.com" as the sender.
    // Use a stable display name while keeping the address the same as the authenticated Gmail account.
    const displayName = envOptional("GMAIL_FROM_NAME") ?? "EstateMate";
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
      // Mark row as failed.
      await admin
        .from("openhouse_auto_emails")
        .update({ status: "failed", error_message: JSON.stringify(sendJson).slice(0, 1000) })
        .eq("created_by", userId)
        .eq("submission_id", submissionId);

      return new Response(
        JSON.stringify({ error: "gmail_send_failed", detail: sendJson }),
        { status: 502, headers: { "content-type": "application/json" } },
      );
    }

    const providerMessageId = (sendJson?.id as string | undefined) ?? null;

    await admin
      .from("openhouse_auto_emails")
      .update({
        status: "sent",
        sent_at: new Date().toISOString(),
        provider_message_id: providerMessageId,
        from_email: fromEmail,
      })
      .eq("created_by", userId)
      .eq("submission_id", submissionId);

    return new Response(
      JSON.stringify({ ok: true, alreadySent: false, id: providerMessageId }),
      { headers: { "content-type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
