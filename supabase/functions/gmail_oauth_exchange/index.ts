import { supabaseServiceClient, supabaseClientForUser } from "../_shared/supabase.ts";

type ExchangeBody = {
  code: string;
  codeVerifier: string;
  redirectUri: string;
};

async function googleTokenExchange(body: ExchangeBody) {
  const clientId = Deno.env.get("GOOGLE_OAUTH_WEB_CLIENT_ID")!;
  const clientSecret = Deno.env.get("GOOGLE_OAUTH_WEB_CLIENT_SECRET")!;

  const params = new URLSearchParams();
  params.set("client_id", clientId);
  params.set("client_secret", clientSecret);
  params.set("grant_type", "authorization_code");
  params.set("code", body.code);
  params.set("code_verifier", body.codeVerifier);
  params.set("redirect_uri", body.redirectUri);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: params,
  });

  const json = await res.json();
  if (!res.ok) {
    throw new Error(`google_token_exchange_failed: ${JSON.stringify(json)}`);
  }
  return json as {
    access_token: string;
    expires_in: number;
    refresh_token?: string;
    scope?: string;
    token_type: string;
    id_token?: string;
  };
}

async function fetchUserEmail(accessToken: string): Promise<string | null> {
  const res = await fetch("https://www.googleapis.com/oauth2/v2/userinfo", {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });
  if (!res.ok) return null;
  const json = await res.json();
  return (json?.email as string) ?? null;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "method_not_allowed" }), {
        status: 405,
        headers: { "content-type": "application/json" },
      });
    }

    const userClient = supabaseClientForUser(req);
    const { data: userRes, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userRes?.user) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { "content-type": "application/json" },
      });
    }

    const payload = (await req.json()) as Partial<ExchangeBody>;
    if (!payload.code || !payload.codeVerifier || !payload.redirectUri) {
      return new Response(JSON.stringify({ error: "bad_request" }), {
        status: 400,
        headers: { "content-type": "application/json" },
      });
    }

    const token = await googleTokenExchange({
      code: payload.code,
      codeVerifier: payload.codeVerifier,
      redirectUri: payload.redirectUri,
    } as ExchangeBody);

    // refresh_token is only returned on first consent or if prompt=consent.
    if (!token.refresh_token) {
      return new Response(
        JSON.stringify({
          error: "missing_refresh_token",
          hint: "Google 未返回 refresh_token。请确保 prompt=consent 且 access_type=offline，并在 Google 账号里撤销对 EstateMate 的授权后重试。",
        }),
        { status: 400, headers: { "content-type": "application/json" } },
      );
    }

    const email = (await fetchUserEmail(token.access_token)) ?? userRes.user.email ?? null;

    const admin = supabaseServiceClient();
    const { error: upsertErr } = await admin
      .from("gmail_connections")
      .upsert({
        user_id: userRes.user.id,
        email,
        refresh_token: token.refresh_token,
        scope: token.scope ?? null,
      });

    if (upsertErr) {
      return new Response(JSON.stringify({ error: upsertErr.message }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ connected: true, email }),
      { headers: { "content-type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
