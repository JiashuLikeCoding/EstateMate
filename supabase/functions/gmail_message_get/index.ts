import { requireUser, supabaseServiceClient } from "../_shared/supabase.ts";

type Body = {
  messageId: string;
};

type GmailMessage = {
  id: string;
  threadId?: string;
  snippet?: string;
  internalDate?: string;
  payload?: {
    mimeType?: string;
    headers?: { name: string; value: string }[];
    body?: { data?: string };
    parts?: any[];
  };
};

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

  return json as { access_token: string; expires_in: number; token_type: string };
}

function b64UrlToBytes(s: string): Uint8Array {
  const t = s.replace(/-/g, "+").replace(/_/g, "/");
  const pad = t.length % 4 === 0 ? "" : "=".repeat(4 - (t.length % 4));
  const bin = atob(t + pad);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function decodeUtf8(bytes: Uint8Array): string {
  return new TextDecoder("utf-8").decode(bytes);
}

function findBestBody(payload: any): { mimeType: string; text: string } {
  // Prefer text/plain; fallback to text/html.
  const candidates: { mimeType: string; data: string }[] = [];

  function walk(node: any) {
    if (!node) return;
    const mt = node.mimeType;
    const data = node.body?.data;
    if (mt && data && (mt === "text/plain" || mt === "text/html")) {
      candidates.push({ mimeType: mt, data });
    }
    const parts = node.parts as any[] | undefined;
    if (parts) for (const p of parts) walk(p);
  }

  walk(payload);

  const plain = candidates.find((c) => c.mimeType === "text/plain");
  const html = candidates.find((c) => c.mimeType === "text/html");
  const pick = plain ?? html;
  if (!pick) return { mimeType: payload?.mimeType ?? "", text: "" };

  const bytes = b64UrlToBytes(pick.data);
  const text = decodeUtf8(bytes);
  return { mimeType: pick.mimeType, text };
}

function headerValue(headers: { name: string; value: string }[] | undefined, name: string): string {
  const v = headers?.find((h) => h.name.toLowerCase() === name.toLowerCase())?.value;
  return (v ?? "").trim();
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
    const messageId = (body.messageId ?? "").trim();
    if (!messageId) {
      return new Response(JSON.stringify({ error: "bad_request", hint: "Missing messageId" }), {
        status: 400,
        headers: { "content-type": "application/json" },
      });
    }

    const admin = supabaseServiceClient();
    const { data: conn, error: connErr } = await admin
      .from("gmail_connections")
      .select("email,refresh_token")
      .eq("user_id", user!.id)
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

    const getUrl = new URL(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${messageId}`);
    getUrl.searchParams.set("format", "full");

    const getRes = await fetch(getUrl, {
      headers: { Authorization: `Bearer ${token.access_token}` },
    });

    const msgJson = (await getRes.json().catch(() => ({}))) as GmailMessage;
    if (!getRes.ok) {
      return new Response(JSON.stringify({ error: "gmail_get_failed", detail: msgJson }), {
        status: 502,
        headers: { "content-type": "application/json" },
      });
    }

    const headers = msgJson.payload?.headers ?? [];
    const subject = headerValue(headers, "Subject");
    const from = headerValue(headers, "From");
    const to = headerValue(headers, "To");
    const date = headerValue(headers, "Date");
    const messageIdHeader = headerValue(headers, "Message-ID");
    const references = headerValue(headers, "References");

    const bodyPick = findBestBody(msgJson.payload);

    return new Response(
      JSON.stringify({
        ok: true,
        id: msgJson.id,
        threadId: msgJson.threadId ?? null,
        subject,
        from,
        to,
        date,
        snippet: msgJson.snippet ?? "",
        internalDate: msgJson.internalDate ?? null,
        messageId: messageIdHeader,
        references,
        body: {
          mimeType: bodyPick.mimeType,
          text: bodyPick.text,
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
