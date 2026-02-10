import { requireUser, supabaseServiceClient } from "../_shared/supabase.ts";

type Body = {
  contactEmail: string;
  max?: number;
};

type GmailMessageListItem = { id: string; threadId?: string };

type GmailHeaders = { name: string; value: string }[];

type GmailMessage = {
  id: string;
  threadId?: string;
  snippet?: string;
  internalDate?: string;
  payload?: {
    headers?: GmailHeaders;
  };
};

function headerValue(headers: GmailHeaders | undefined, name: string): string {
  const v = headers?.find((h) => h.name.toLowerCase() === name.toLowerCase())?.value;
  return (v ?? "").trim();
}

function normalizeEmail(s: string): string {
  return s.trim().toLowerCase();
}

function extractEmails(s: string): string[] {
  // Best-effort parse emails out of header values.
  const matches = s.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi);
  return (matches ?? []).map((x) => normalizeEmail(x));
}

async function googleRefreshAccessToken(refreshToken: string) {
  const clientId = Deno.env.get("GOOGLE_OAUTH_WEB_CLIENT_ID") || Deno.env.get("GOOGLE_OAUTH_CLIENT_ID") || "";
  const clientSecret = Deno.env.get("GOOGLE_OAUTH_WEB_CLIENT_SECRET") || Deno.env.get("GOOGLE_OAUTH_CLIENT_SECRET") || "";

  if (!clientId.trim()) throw new Error("Missing env: GOOGLE_OAUTH_WEB_CLIENT_ID (or GOOGLE_OAUTH_CLIENT_ID)");

  const params = new URLSearchParams();
  params.set("client_id", clientId);
  // iOS client has no secret; only set if present.
  if (clientSecret.trim()) params.set("client_secret", clientSecret);
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

  return json as { access_token: string; expires_in: number; token_type: string };
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

    const body = (await req.json()) as Partial<Body>;
    const contactEmail = (body.contactEmail ?? "").trim();
    const max = Math.min(Math.max(Number(body.max ?? 20), 1), 50);

    if (!contactEmail) {
      return new Response(JSON.stringify({ error: "bad_request", hint: "Missing contactEmail" }), {
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

    const me = (conn.email ?? "").trim();
    if (!me) {
      return new Response(JSON.stringify({ error: "gmail_connection_missing_email" }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }

    if (normalizeEmail(contactEmail) === normalizeEmail(me)) {
      return new Response(
        JSON.stringify({ ok: true, messages: [], hint: "联系人邮箱与当前连接的 Gmail 相同，无法筛选往来对象。" }),
        { headers: { "content-type": "application/json" } },
      );
    }

    // Only messages between: me <-> contactEmail
    // (Gmail search supports AND by space)
    const q = `((from:${contactEmail} to:${me}) OR (from:${me} to:${contactEmail}))`;
    const listUrl = new URL("https://gmail.googleapis.com/gmail/v1/users/me/messages");
    listUrl.searchParams.set("q", q);
    listUrl.searchParams.set("maxResults", String(max));

    const listRes = await fetch(listUrl, {
      headers: { Authorization: `Bearer ${token.access_token}` },
    });

    const listJson = await listRes.json().catch(() => ({}));
    if (!listRes.ok) {
      return new Response(JSON.stringify({ error: "gmail_list_failed", detail: listJson }), {
        status: 502,
        headers: { "content-type": "application/json" },
      });
    }

    const messages = (listJson?.messages as GmailMessageListItem[] | undefined) ?? [];

    // Fetch metadata for each message.
    const details: any[] = [];

    for (const m of messages) {
      const getUrl = new URL(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${m.id}`);
      getUrl.searchParams.set("format", "metadata");
      getUrl.searchParams.append("metadataHeaders", "Subject");
      getUrl.searchParams.append("metadataHeaders", "From");
      getUrl.searchParams.append("metadataHeaders", "To");
      getUrl.searchParams.append("metadataHeaders", "Date");

      const getRes = await fetch(getUrl, {
        headers: { Authorization: `Bearer ${token.access_token}` },
      });
      const msgJson = (await getRes.json().catch(() => ({}))) as GmailMessage;
      if (!getRes.ok) continue;

      const headers = msgJson.payload?.headers ?? [];
      const subject = headerValue(headers, "Subject");
      const from = headerValue(headers, "From");
      const to = headerValue(headers, "To");
      const date = headerValue(headers, "Date");

      const fromEmails = extractEmails(from);
      const toEmails = extractEmails(to);

      const contactNorm = normalizeEmail(contactEmail);
      const meNorm = normalizeEmail(me);

      const isInbound = fromEmails.includes(contactNorm) && toEmails.includes(meNorm);
      const isOutbound = fromEmails.includes(meNorm) && toEmails.includes(contactNorm);

      // Hard filter to only messages between me <-> contact.
      if (!isInbound && !isOutbound) continue;

      details.push({
        id: msgJson.id,
        threadId: msgJson.threadId ?? null,
        direction: isInbound ? "inbound" : "outbound",
        subject,
        from,
        to,
        date,
        snippet: msgJson.snippet ?? "",
        internalDate: msgJson.internalDate ?? null,
      });
    }

    // Sort by internalDate desc if present.
    details.sort((a, b) => Number(b.internalDate ?? 0) - Number(a.internalDate ?? 0));

    return new Response(
      JSON.stringify({
        ok: true,
        messages: details,
        debug: {
          me,
          contactEmail,
          q,
          fetched: messages.length,
          kept: details.length,
        },
      }),
      { headers: { "content-type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
