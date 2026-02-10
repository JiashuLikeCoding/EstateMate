import { supabaseClientForUser, supabaseServiceClient } from "../_shared/supabase.ts";

type Body = {
  to: string;
  subject: string;
  text: string;
  replyTo?: string;
  // optional context
  contactId?: string;
  submissionId?: string;
};

async function resendSendEmail(params: {
  from: string;
  to: string;
  subject: string;
  text: string;
  replyTo?: string;
}) {
  const apiKey = Deno.env.get("RESEND_API_KEY")!;
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: params.from,
      to: [params.to],
      subject: params.subject,
      text: params.text,
      reply_to: params.replyTo,
    }),
  });

  const json = await res.json();
  if (!res.ok) {
    throw new Error(`resend_send_failed: ${JSON.stringify(json)}`);
  }
  return json as { id: string };
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "method_not_allowed" }), {
        status: 405,
        headers: { "content-type": "application/json" },
      });
    }

    const from = Deno.env.get("RESEND_FROM") ?? "";
    if (!from) {
      return new Response(
        JSON.stringify({ error: "missing_resend_from", hint: "Set RESEND_FROM in Edge Function secrets." }),
        { status: 500, headers: { "content-type": "application/json" } },
      );
    }

    const userClient = supabaseClientForUser(req);
    const { data: userRes, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userRes?.user) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { "content-type": "application/json" },
      });
    }

    const body = (await req.json()) as Partial<Body>;
    if (!body.to || !body.subject || !body.text) {
      return new Response(JSON.stringify({ error: "bad_request" }), {
        status: 400,
        headers: { "content-type": "application/json" },
      });
    }

    const replyTo = body.replyTo ?? userRes.user.email ?? undefined;

    const sendRes = await resendSendEmail({
      from,
      to: body.to,
      subject: body.subject,
      text: body.text,
      replyTo,
    });

    // Best-effort CRM log (only if contactId provided)
    if (body.contactId) {
      const admin = supabaseServiceClient();
      await admin.from("crm_email_logs").insert({
        created_by: userRes.user.id,
        contact_id: body.contactId,
        direction: "outbound",
        subject: body.subject,
        body: body.text,
        sent_at: new Date().toISOString(),
        // optional fields may not exist in older schema; insert ignores unknown keys in PostgREST? (it won't) 
      });
    }

    return new Response(JSON.stringify({ ok: true, id: sendRes.id }), {
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
